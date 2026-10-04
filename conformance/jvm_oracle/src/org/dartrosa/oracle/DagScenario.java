package org.dartrosa.oracle;

import com.fasterxml.jackson.databind.JsonNode;
import java.io.File;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.javarosa.core.model.FormDef;
import org.javarosa.core.model.GroupDef;
import org.javarosa.core.model.IFormElement;
import org.javarosa.core.model.actions.Actions;
import org.javarosa.core.model.condition.EvaluationContext;
import org.javarosa.core.model.data.IAnswerData;
import org.javarosa.core.model.instance.FormInstance;
import org.javarosa.core.model.instance.InstanceInitializationFactory;
import org.javarosa.core.model.instance.TreeElement;
import org.javarosa.core.model.instance.TreeReference;
import org.javarosa.test.Scenario;
import org.javarosa.xform.util.XFormAnswerDataParser;

/**
 * Drives FormDef directly (no FormEntryController): initialize, then
 * setValue / createRepeat / deleteRepeat / constraint / repeatRelevant /
 * postProcess steps, dumping the main instance after each. Repeat
 * creation and deletion replay FormDef.createNewRepeat / deleteRepeat after
 * their FormIndex-to-reference step (DartRosa's reference-based core).
 */
final class DagScenario {
    private DagScenario() {}

    static Map<String, Object> run(File scenarioFile, File root) throws Exception {
        JsonNode scenario = Oracle.JSON.readTree(scenarioFile);
        String formPath = scenario.get("form").asText();
        Map<String, Object> trace = new LinkedHashMap<>();
        trace.put("traceVersion", Oracle.TRACE_VERSION);
        trace.put("form", formPath);
        File form = new File(root, formPath);
        Oracle.setUpReferences(form.getAbsoluteFile().getParentFile());
        FormDef def = Scenario.createFormDef(form);
        def.initialize(true, new InstanceInitializationFactory());
        List<Object> steps = new ArrayList<>();
        for (JsonNode step : scenario.get("steps")) {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("step", Oracle.JSON.convertValue(step, Map.class));
            try {
                Object result = apply(def, step);
                if (result != null) out.put("result", result);
            } catch (Throwable t) {
                out.put("error", Oracle.stableError(t));
            }
            out.put("instance", Structure.tree(def.getMainInstance().getRoot()));
            steps.add(out);
        }
        trace.put("steps", steps);
        return trace;
    }

    static Object apply(FormDef def, JsonNode step) throws Exception {
        String op = step.get("op").asText();
        TreeReference ref = step.has("ref") ? Scenario.getRef(step.get("ref").asText()) : null;
        switch (op) {
            case "setValue": {
                TreeElement node = def.getMainInstance().resolveReference(ref);
                IAnswerData data = step.get("value").isNull() ? null
                    : XFormAnswerDataParser.getAnswerData(step.get("value").asText(), node.getDataType(), null);
                def.setValue(data, ref, true);
                return null;
            }
            case "createRepeat": {
                FormInstance main = def.getMainInstance();
                TreeElement template = main.getTemplate(ref);
                main.copyNode(template, ref);
                TreeElement newNode = main.resolveReference(ref);
                def.preloadInstance(newNode);
                def.getActionController().triggerActionsFromEvent(Actions.EVENT_JR_INSERT, def, ref, def);
                def.getActionController().triggerActionsFromEvent(Actions.EVENT_ODK_NEW_REPEAT, def, ref, def);
                GroupDef repeat = findRepeat(def, ref.genericize());
                if (repeat != null) {
                    repeat.getActionController().triggerActionsFromEvent(Actions.EVENT_ODK_NEW_REPEAT, def, ref, def);
                }
                dag(def, "createRepeatInstance", ref, newNode);
                return null;
            }
            case "deleteRepeat": {
                FormInstance main = def.getMainInstance();
                TreeElement deleteElement = main.resolveReference(ref);
                TreeElement parentElement = main.resolveReference(ref.getParentRef());
                int childMult = deleteElement.getMult();
                parentElement.removeChild(deleteElement);
                for (int i = 0; i < parentElement.getNumChildren(); i++) {
                    TreeElement child = parentElement.getChildAt(i);
                    if (child.getName().equals(deleteElement.getName()) && child.getMult() > childMult) {
                        child.setMult(child.getMult() - 1);
                        child.clearChildrenCaches();
                    }
                }
                dag(def, "deleteRepeatInstance", ref, deleteElement);
                return null;
            }
            case "constraint": {
                TreeElement node = def.getMainInstance().resolveReference(ref);
                IAnswerData data = step.get("value").isNull() ? null
                    : XFormAnswerDataParser.getAnswerData(step.get("value").asText(), node.getDataType(), null);
                return def.evaluateConstraint(ref, data);
            }
            case "repeatRelevant":
                return def.isRepeatRelevant(ref);
            case "postProcess":
                def.postProcessInstance();
                return null;
            default:
                throw new IllegalArgumentException("unknown op " + op);
        }
    }

    static void dag(FormDef def, String method, TreeReference ref, TreeElement element) throws Exception {
        java.lang.reflect.Field f = FormDef.class.getDeclaredField("dagImpl");
        f.setAccessible(true);
        Object dag = f.get(def);
        Method m = dag.getClass().getDeclaredMethod(method, FormInstance.class, EvaluationContext.class,
            TreeReference.class, TreeElement.class);
        m.setAccessible(true);
        try {
            m.invoke(dag, def.getMainInstance(), def.getEvaluationContext(), ref, element);
        } catch (java.lang.reflect.InvocationTargetException e) {
            throw (Exception) e.getCause();
        }
    }

    static GroupDef findRepeat(IFormElement element, TreeReference generic) {
        if (element.getChildren() == null) return null;
        for (IFormElement child : element.getChildren()) {
            if (child instanceof GroupDef g) {
                if (g.getRepeat() && g.getBind() != null
                    && ((TreeReference) g.getBind().getReference()).genericize().equals(generic)) {
                    return g;
                }
                GroupDef found = findRepeat(child, generic);
                if (found != null) return found;
            }
        }
        return null;
    }
}
