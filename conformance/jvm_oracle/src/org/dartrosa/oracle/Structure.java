package org.dartrosa.oracle;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.javarosa.core.model.FormDef;
import org.javarosa.core.model.GroupDef;
import org.javarosa.core.model.IFormElement;
import org.javarosa.core.model.ItemsetBinding;
import org.javarosa.core.model.QuestionDef;
import org.javarosa.core.model.SelectChoice;
import org.javarosa.core.model.SubmissionProfile;
import org.javarosa.core.model.condition.Condition;
import org.javarosa.core.model.condition.Constraint;
import org.javarosa.core.model.condition.IConditionExpr;
import org.javarosa.core.model.condition.Triggerable;
import org.javarosa.core.model.instance.DataInstance;
import org.javarosa.core.model.instance.TreeElement;
import org.javarosa.core.model.instance.TreeReference;
import org.javarosa.core.services.locale.Localizer;
import org.javarosa.xpath.XPathConditional;

/**
 * Dumps a parsed FormDef as JSON-friendly maps (the "structure" trace, see
 * conformance/TRACE_FORMAT.md). DartRosa builds the same structure.
 */
final class Structure {
    private Structure() {}

    static Map<String, Object> of(FormDef f) {
        Map<String, Object> s = new LinkedHashMap<>();
        s.put("title", f.getTitle());
        s.put("name", f.getName());
        Localizer l = f.getLocalizer();
        s.put("languages", l == null ? null : List.of(l.getAvailableLocales()));
        s.put("defaultLanguage", l == null ? null : l.getDefaultLocale());
        s.put("elements", elements(f));
        s.put("instance", tree(f.getMainInstance().getRoot()));
        Map<String, Object> secondary = new LinkedHashMap<>();
        for (Map.Entry<String, DataInstance> e : f.getFormInstances().entrySet()) {
            secondary.put(e.getKey(), tree((TreeElement) e.getValue().getRoot()));
        }
        s.put("secondaryInstances", secondary);
        List<Object> triggerables = new ArrayList<>();
        // JavaRosa keeps triggerables in a HashSet: sort for a stable order.
        List<Map<String, Object>> sorted = new ArrayList<>();
        for (Triggerable t : allTriggerables(f)) sorted.add(triggerable(t));
        sorted.sort(java.util.Comparator.comparing(Structure::sortKey));
        triggerables.addAll(sorted);
        s.put("triggerables", triggerables);
        List<Object> outputs = new ArrayList<>();
        for (IConditionExpr e : f.getOutputFragments()) outputs.add(e.getExpr().toString());
        s.put("outputs", outputs);
        SubmissionProfile p = f.getSubmissionProfile();
        s.put("submission", p == null ? null : Map.of(
            "ref", ref((TreeReference) p.getRef().getReference()),
            "method", String.valueOf(p.getMethod()),
            "action", String.valueOf(p.getAction())));
        s.put("warnings", f.getParseWarnings());
        return s;
    }

    static List<Object> elements(IFormElement parent) {
        List<Object> out = new ArrayList<>();
        if (parent.getChildren() == null) return out;
        for (IFormElement e : parent.getChildren()) {
            Map<String, Object> m = new LinkedHashMap<>();
            if (e instanceof GroupDef g) {
                m.put("kind", g.getRepeat() ? "repeat" : "group");
                m.put("count", g.count == null ? null : ref((TreeReference) g.count.getReference()));
                m.put("noAddRemove", g.noAddRemove);
            } else {
                QuestionDef q = (QuestionDef) e;
                m.put("kind", "question");
                m.put("control", Oracle.CONTROL_TYPES.getOrDefault(q.getControlType(), String.valueOf(q.getControlType())));
                m.put("helpText", q.getHelpText());
                m.put("helpInnerText", q.getHelpInnerText());
                m.put("helpTextId", q.getHelpTextID());
                List<Object> choices = new ArrayList<>();
                if (q.getChoices() != null) {
                    for (SelectChoice c : q.getChoices()) {
                        Map<String, Object> cm = new LinkedHashMap<>();
                        cm.put("value", c.getValue());
                        cm.put("label", c.getLabelInnerText());
                        cm.put("textId", c.getTextID());
                        cm.put("index", c.getIndex());
                        choices.add(cm);
                    }
                }
                m.put("choices", choices);
                ItemsetBinding i = q.getDynamicChoices();
                if (i != null) {
                    Map<String, Object> im = new LinkedHashMap<>();
                    im.put("nodeset", ref(i.nodesetRef));
                    im.put("label", ref(i.labelRef));
                    im.put("value", i.valueRef == null ? null : ref(i.valueRef));
                    im.put("labelIsItext", i.labelIsItext);
                    im.put("randomize", i.randomize);
                    im.put("seed", i.randomSeedExpr == null ? null : i.randomSeedExpr.toString());
                    im.put("filter", i.nodesetExpr.getExpr().toString());
                    m.put("itemset", im);
                }
            }
            m.put("ref", e.getBind() == null ? null : ref((TreeReference) e.getBind().getReference()));
            m.put("appearance", e.getAppearanceAttr());
            m.put("label", e.getLabelInnerText());
            m.put("textId", e.getTextID());
            List<Object> attrs = new ArrayList<>();
            for (TreeElement a : e.getAdditionalAttributes()) {
                attrs.add(List.of(String.valueOf(a.getNamespace()), a.getName(), String.valueOf(a.getAttributeValue())));
            }
            m.put("attributes", attrs);
            m.put("children", elements(e));
            out.add(m);
        }
        return out;
    }

    static Map<String, Object> tree(TreeElement t) {
        Map<String, Object> m = new LinkedHashMap<>();
        if (t == null) return m;
        m.put("name", t.getName());
        m.put("mult", t.getMult());
        m.put("type", Oracle.DATA_TYPES.getOrDefault(t.getDataType(), String.valueOf(t.getDataType())));
        m.put("value", t.getValue() == null ? null : Oracle.normalize(t.getValue().uncast().getString()));
        m.put("relevant", t.isRelevant());
        m.put("required", t.isRequired());
        m.put("enabled", t.isEnabled());
        m.put("repeatable", t.isRepeatable());
        m.put("namespace", t.getNamespace());
        m.put("prefix", t.getNamespacePrefix());
        m.put("preload", t.getPreloadHandler());
        m.put("preloadParams", t.getPreloadParams());
        Constraint c = t.getConstraint();
        m.put("constraint", c == null ? null : c.constraint.getExpr().toString());
        List<Object> attrs = new ArrayList<>();
        for (int i = 0; i < t.getAttributeCount(); i++) {
            attrs.add(List.of(String.valueOf(t.getAttributeNamespace(i)), t.getAttributeName(i), String.valueOf(Oracle.normalize(t.getAttributeValue(i)))));
        }
        m.put("attributes", attrs);
        List<Object> bindAttrs = new ArrayList<>();
        for (TreeElement a : t.getBindAttributes()) {
            bindAttrs.add(List.of(String.valueOf(a.getNamespace()), a.getName(), String.valueOf(a.getAttributeValue())));
        }
        m.put("bindAttributes", bindAttrs);
        List<Object> children = new ArrayList<>();
        for (int i = 0; i < t.getNumChildren(); i++) children.add(tree(t.getChildAt(i)));
        m.put("children", children);
        return m;
    }

    static Map<String, Object> triggerable(Triggerable t) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("kind", t instanceof Condition ? "condition" : "recalculate");
        m.put("expr", ((XPathConditional) t.getExpr()).getExpr().toString());
        m.put("context", ref(t.getContext()));
        m.put("originalContext", ref(t.getOriginalContext()));
        List<String> targets = new ArrayList<>();
        for (TreeReference r : t.getTargets()) targets.add(ref(r));
        targets.sort(null);
        m.put("targets", targets);
        List<String> triggers = new ArrayList<>();
        for (TreeReference r : t.getTriggers()) triggers.add(ref(r));
        triggers.sort(null);
        m.put("triggers", triggers);
        return m;
    }

    /** Registration order, via TriggerableDag.allTriggerables (reflection). */
    @SuppressWarnings("unchecked")
    static List<Triggerable> allTriggerables(FormDef f) {
        try {
            Field dag = FormDef.class.getDeclaredField("dagImpl");
            dag.setAccessible(true);
            Object d = dag.get(f);
            Field all = d.getClass().getDeclaredField("allTriggerables");
            all.setAccessible(true);
            List<Triggerable> out = new ArrayList<>();
            for (Object q : (Iterable<Object>) all.get(d)) {
                Field tf = q.getClass().getDeclaredField("triggerable");
                tf.setAccessible(true);
                out.add((Triggerable) tf.get(q));
            }
            return out;
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
    }

    /** Each triggerable's immediate cascades, both sorted by sortKey. */
    static List<Object> cascades(FormDef f) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Triggerable t : allTriggerables(f)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("triggerable", sortKey(triggerable(t)));
            List<String> cascades = new ArrayList<>();
            if (t.getImmediateCascades() != null) {
                for (org.javarosa.core.model.QuickTriggerable qt : t.getImmediateCascades()) {
                    cascades.add(sortKey(triggerable(qt.getTriggerable())));
                }
            }
            cascades.sort(null);
            m.put("cascades", cascades);
            out.add(m);
        }
        out.sort(java.util.Comparator.comparing(m -> (String) m.get("triggerable")));
        return new ArrayList<>(out);
    }

    static String sortKey(Map<String, Object> t) {
        return t.get("kind") + "|" + t.get("expr") + "|" + t.get("originalContext") + "|" + t.get("targets");
    }

    static String ref(TreeReference r) {
        return r == null ? null : r.toString(true);
    }
}
