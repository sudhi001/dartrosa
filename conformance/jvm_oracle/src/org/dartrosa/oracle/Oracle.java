package org.dartrosa.oracle;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import org.javarosa.core.model.Constants;
import org.javarosa.core.model.FormDef;
import org.javarosa.core.model.FormIndex;
import org.javarosa.core.model.QuestionDef;
import org.javarosa.core.model.SelectChoice;
import org.javarosa.core.model.ValidateOutcome;
import org.javarosa.core.model.data.IAnswerData;
import org.javarosa.core.model.instance.TreeReference;
import org.javarosa.core.reference.ReferenceManager;
import org.javarosa.form.api.FormEntryController;
import org.javarosa.form.api.FormEntryModel;
import org.javarosa.form.api.FormEntryPrompt;
import org.javarosa.model.xform.XFormSerializingVisitor;
import org.javarosa.test.Scenario;
import org.javarosa.xform.util.XFormAnswerDataParser;

/**
 * Runs forms and scenarios through real JavaRosa and prints canonical JSON
 * traces. DartRosa emits the same format; CI diffs the two.
 * See conformance/TRACE_FORMAT.md.
 */
public final class Oracle {
    static final int TRACE_VERSION = 1;
    static final int MAX_EVENTS = 20_000;
    static final String[] MEDIA_SCHEMES = {"file", "file-csv", "images", "audio", "video"};

    static final ObjectMapper JSON = new ObjectMapper()
        .enable(SerializationFeature.INDENT_OUTPUT)
        .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS);

    static final Map<Integer, String> CONTROL_TYPES = constantNames("CONTROL_");
    static final Map<Integer, String> DATA_TYPES = constantNames("DATATYPE_");

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("usage: walk <form.xml> | scenario <file.scenario.json> | batch <conformance-dir> | doubles <out.json>");
            System.exit(64);
        }
        switch (args[0]) {
            case "walk" -> print(walkTrace(new File(args[1]), args[1]));
            case "scenario" -> print(scenarioTrace(new File(args[1]), conformanceRootOf(new File(args[1]))));
            case "batch" -> batch(new File(args[1]));
            case "doubles" -> doubles(new File(args[1]));
            default -> { System.err.println("unknown command " + args[0]); System.exit(64); }
        }
    }

    // ---------------------------------------------------------------- numbers

    /**
     * Writes Java's {@code Double.toString} for edge cases and 10,000 seeded
     * random doubles. Doubles are keyed by their IEEE-754 bits (hex) so no
     * precision is lost on the way to Dart.
     */
    static void doubles(File out) throws Exception {
        List<Double> values = new ArrayList<>(List.of(
            0.0, -0.0, 1.0, -1.0, 10.0, 0.1, 0.5, 123.0, 734.04, 0.12345, 0.666, 333.333,
            1.23e21, 1.23e-18, 1e7, 9999999.0, 9999999.999999, 1e-3, 0.00099999, 1e-4,
            100.0, 1e21, 1e22, 1e23, 2e-323, Double.MIN_VALUE, Double.MAX_VALUE, Double.MIN_NORMAL,
            Math.PI, Math.E, 1.0 / 3, 2.0 / 3, 0.1 + 0.2, 1e16, 12345678.9, 4.35, 2.675,
            Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY));
        java.util.Random random = new java.util.Random(20261003L);
        for (int i = 0; i < 4000; i++) values.add(Double.longBitsToDouble(random.nextLong())); // any bit pattern
        for (int i = 0; i < 3000; i++) values.add((random.nextDouble() - 0.5) * Math.pow(10, random.nextInt(30) - 10));
        for (int i = 0; i < 3000; i++) values.add(Math.round(random.nextDouble() * 1e6) / Math.pow(10, random.nextInt(8)));
        List<Object> cases = new ArrayList<>();
        for (double d : values) {
            if (Double.isNaN(d) && Double.doubleToRawLongBits(d) != Double.doubleToLongBits(Double.NaN)) continue;
            cases.add(List.of(Long.toHexString(Double.doubleToRawLongBits(d)), Double.toString(d)));
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("java", System.getProperty("java.version"));
        result.put("cases", cases);
        Files.writeString(out.toPath(), new ObjectMapper().writeValueAsString(result) + "\n");
        System.err.printf("oracle: %d doubles written to %s%n", cases.size(), out);
    }

    // ---------------------------------------------------------------- batch

    static void batch(File conformance) throws Exception {
        Path root = conformance.toPath();
        Path forms = root.resolve("forms");
        Path scenarios = root.resolve("scenarios");
        Path traces = root.resolve("traces");
        int ok = 0, failed = 0;

        for (Path form : list(forms, ".xml", ".xhtml")) {
            if (!isXForm(form)) continue; // secondary-instance data files
            String rel = forms.relativize(form).toString();
            Map<String, Object> trace = walkTrace(form.toFile(), "forms/" + rel);
            if (!(boolean) ((Map<?, ?>) trace.get("parse")).get("ok")) failed++; else ok++;
            write(traces.resolve("walk").resolve(rel + ".json"), trace);
            write(traces.resolve("structure").resolve(rel + ".json"), structureTrace(form.toFile(), "forms/" + rel));
            write(traces.resolve("init").resolve(rel + ".json"), initTrace(form.toFile(), "forms/" + rel));
        }
        for (Path dag : list(scenarios, ".dag.json")) {
            String rel = scenarios.relativize(dag).toString();
            write(traces.resolve("dag").resolve(rel), DagScenario.run(dag.toFile(), root.toFile()));
            ok++;
        }
        for (Path scenario : list(scenarios, ".scenario.json")) {
            String rel = scenarios.relativize(scenario).toString();
            write(traces.resolve("scenarios").resolve(rel), scenarioTrace(scenario.toFile(), root.toFile()));
            ok++;
        }
        System.err.printf("oracle: %d traces written, %d forms failed to parse (recorded in their traces)%n", ok + failed, failed);
    }

    static boolean isXForm(Path file) throws Exception {
        String head = new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
        return head.contains("<h:html") || head.contains("<html");
    }

    /** Scenario form paths are relative to the nearest ancestor holding {@code forms/}. */
    static File conformanceRootOf(File scenario) {
        for (File dir = scenario.getAbsoluteFile().getParentFile(); dir != null; dir = dir.getParentFile()) {
            if (new File(dir, "forms").isDirectory()) return dir;
        }
        return scenario.getAbsoluteFile().getParentFile();
    }

    static List<Path> list(Path dir, String... suffixes) throws Exception {
        if (!Files.isDirectory(dir)) return List.of();
        try (Stream<Path> s = Files.walk(dir)) {
            return s.filter(Files::isRegularFile)
                .filter(p -> Stream.of(suffixes).anyMatch(x -> p.toString().endsWith(x)))
                .sorted().toList();
        }
    }

    // ---------------------------------------------------------------- traces

    static Map<String, Object> walkTrace(File form, String displayPath) {
        Map<String, Object> scenario = new LinkedHashMap<>();
        scenario.put("steps", List.of(Map.of("op", "walk"), Map.of("op", "validate")));
        return run(form, displayPath, JSON.valueToTree(scenario));
    }

    static Map<String, Object> structureTrace(File form, String displayPath) {
        Map<String, Object> trace = new LinkedHashMap<>();
        trace.put("traceVersion", TRACE_VERSION);
        trace.put("form", displayPath);
        try {
            setUpReferences(form.getAbsoluteFile().getParentFile());
            FormDef def = Scenario.createFormDef(form);
            trace.put("parse", Map.of("ok", true));
            trace.put("structure", Structure.of(def));
        } catch (Throwable t) {
            trace.put("parse", Map.of("ok", false, "error", error(t)));
        }
        return trace;
    }

    /** Dependency graph and the instance after initialize(newInstance = true). */
    static Map<String, Object> initTrace(File form, String displayPath) {
        Map<String, Object> trace = new LinkedHashMap<>();
        trace.put("traceVersion", TRACE_VERSION);
        trace.put("form", displayPath);
        FormDef def;
        try {
            setUpReferences(form.getAbsoluteFile().getParentFile());
            def = Scenario.createFormDef(form);
        } catch (Throwable t) {
            trace.put("parse", Map.of("ok", false, "error", stableError(t)));
            return trace;
        }
        trace.put("parse", Map.of("ok", true));
        trace.put("cascades", Structure.cascades(def));
        try {
            def.initialize(true, new org.javarosa.core.model.instance.InstanceInitializationFactory());
            trace.put("initialize", Map.of("ok", true));
        } catch (Throwable t) {
            trace.put("initialize", Map.of("ok", false, "error", stableError(t)));
        }
        trace.put("instance", Structure.tree(def.getMainInstance().getRoot()));
        return trace;
    }

    /**
     * error(t), with the node lines of a cycle message sorted: JavaRosa lists
     * them in identity-hash order, which changes between runs.
     */
    static Map<String, Object> stableError(Throwable t) {
        Map<String, Object> e = new LinkedHashMap<>(error(t));
        Object message = e.get("message");
        String marker = "The following nodes are likely involved in the loop:";
        if (message instanceof String m && m.contains(marker)) {
            int at = m.indexOf(marker) + marker.length();
            List<String> lines = new ArrayList<>(List.of(m.substring(at).split("\n")));
            lines.removeIf(String::isEmpty);
            java.util.Collections.sort(lines);
            e.put("message", m.substring(0, at) + "\n" + String.join("\n", lines));
        }
        return e;
    }

    static Map<String, Object> scenarioTrace(File scenarioFile, File conformanceRoot) throws Exception {
        JsonNode scenario = JSON.readTree(scenarioFile);
        String formPath = scenario.get("form").asText();
        return run(new File(conformanceRoot, formPath), formPath, scenario);
    }

    static Map<String, Object> run(File form, String displayPath, JsonNode scenario) {
        Map<String, Object> trace = new LinkedHashMap<>();
        trace.put("traceVersion", TRACE_VERSION);
        trace.put("form", displayPath);

        Scenario s;
        try {
            setUpReferences(form.getAbsoluteFile().getParentFile());
            s = Scenario.init(form);
        } catch (Throwable t) {
            trace.put("parse", Map.of("ok", false, "error", error(t)));
            return trace;
        }
        FormDef def = s.getFormDef();
        Map<String, Object> parse = new LinkedHashMap<>();
        parse.put("ok", true);
        parse.put("title", def.getTitle());
        parse.put("languages", def.getLocalizer() == null ? List.of() : List.of(def.getLocalizer().getAvailableLocales()));
        parse.put("language", def.getLocalizer() == null ? null : def.getLocalizer().getLocale());
        trace.put("parse", parse);

        List<Object> steps = new ArrayList<>();
        for (JsonNode step : scenario.get("steps")) {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("op", step.get("op").asText());
            try {
                runStep(s, step, result);
            } catch (Throwable t) {
                result.put("error", error(t));
            }
            steps.add(result);
        }
        trace.put("steps", steps);

        try {
            trace.put("instance", normalize(new String(new XFormSerializingVisitor().serializeInstance(def.getInstance()), StandardCharsets.UTF_8)));
        } catch (Throwable t) {
            trace.put("instance", Map.of("error", error(t)));
        }
        return trace;
    }

    static void runStep(Scenario s, JsonNode step, Map<String, Object> out) {
        FormEntryController controller = s.getFormEntryController();
        FormEntryModel model = controller.getModel();
        switch (step.get("op").asText()) {
            case "walk" -> {
                s.jumpToBeginningOfForm();
                List<Object> events = new ArrayList<>();
                int event;
                do {
                    event = controller.stepToNextEvent();
                    events.add(describe(model, event));
                } while (event != FormEntryController.EVENT_END_OF_FORM && events.size() < MAX_EVENTS);
                out.put("events", events);
            }
            case "next" -> out.put("event", describe(model, controller.stepToNextEvent()));
            case "prev" -> out.put("event", describe(model, controller.stepToPreviousEvent()));
            case "jumpToBeginning" -> s.jumpToBeginningOfForm();
            case "answer" -> {
                FormIndex index = s.indexOf(step.get("ref").asText());
                FormEntryPrompt prompt = model.getQuestionPrompt(index);
                JsonNode value = step.get("value");
                IAnswerData data = value == null || value.isNull() || value.asText().isEmpty()
                    ? null
                    : XFormAnswerDataParser.getAnswerData(value.asText(), prompt.getDataType(), prompt.getQuestion());
                out.put("result", switch (controller.answerQuestion(index, data, true)) {
                    case FormEntryController.ANSWER_OK -> "accepted";
                    case FormEntryController.ANSWER_REQUIRED_BUT_EMPTY -> "required";
                    case FormEntryController.ANSWER_CONSTRAINT_VIOLATED -> "constraintViolated";
                    default -> "unknown";
                });
            }
            case "addRepeat" -> s.createNewRepeat(step.get("ref").asText());
            case "removeRepeat" -> s.removeRepeat(step.get("ref").asText());
            case "setLanguage" -> s.setLanguage(step.get("language").asText());
            case "validate" -> {
                ValidateOutcome outcome = s.getValidationOutcome();
                if (outcome == null) { // FormDef.validate() returns null when valid
                    out.put("outcome", "ok");
                    out.put("ref", null);
                    return;
                }
                out.put("outcome", switch (outcome.outcome) {
                    case FormEntryController.ANSWER_OK -> "ok";
                    case FormEntryController.ANSWER_REQUIRED_BUT_EMPTY -> "required";
                    case FormEntryController.ANSWER_CONSTRAINT_VIOLATED -> "constraintViolated";
                    default -> "unknown";
                });
                out.put("ref", outcome.failedPrompt == null ? null : ref(outcome.failedPrompt.getReference()));
            }
            default -> throw new IllegalArgumentException("unknown op " + step.get("op"));
        }
    }

    static Map<String, Object> describe(FormEntryModel model, int event) {
        Map<String, Object> e = new LinkedHashMap<>();
        e.put("event", switch (event) {
            case FormEntryController.EVENT_BEGINNING_OF_FORM -> "beginningOfForm";
            case FormEntryController.EVENT_END_OF_FORM -> "endOfForm";
            case FormEntryController.EVENT_PROMPT_NEW_REPEAT -> "promptNewRepeat";
            case FormEntryController.EVENT_QUESTION -> "question";
            case FormEntryController.EVENT_GROUP -> "group";
            case FormEntryController.EVENT_REPEAT -> "repeat";
            case FormEntryController.EVENT_REPEAT_JUNCTURE -> "repeatJuncture";
            default -> "unknown:" + event;
        });
        FormIndex index = model.getFormIndex();
        if (index.getReference() != null) e.put("ref", ref(index.getReference()));

        if (event == FormEntryController.EVENT_QUESTION) {
            FormEntryPrompt p = model.getQuestionPrompt();
            e.put("control", CONTROL_TYPES.getOrDefault(p.getControlType(), String.valueOf(p.getControlType())));
            e.put("dataType", DATA_TYPES.getOrDefault(p.getDataType(), String.valueOf(p.getDataType())));
            e.put("appearance", p.getAppearanceHint());
            e.put("label", p.getLongText());
            e.put("hint", p.getHelpText());
            e.put("required", p.isRequired());
            e.put("readonly", p.isReadOnly());
            IAnswerData value = p.getAnswerValue();
            e.put("value", value == null ? null : normalize(value.uncast().getString()));
            QuestionDef q = p.getQuestion();
            if (q.getControlType() == Constants.CONTROL_SELECT_ONE
                || q.getControlType() == Constants.CONTROL_SELECT_MULTI
                || q.getControlType() == Constants.CONTROL_RANK) {
                List<Object> choices = new ArrayList<>();
                List<SelectChoice> list = p.getSelectChoices();
                if (list != null) {
                    for (SelectChoice c : list) {
                        Map<String, Object> choice = new LinkedHashMap<>();
                        choice.put("value", c.getValue());
                        choice.put("label", p.getSelectChoiceText(c));
                        choices.add(choice);
                    }
                }
                // Unseeded randomize() is random by design: record a stable order.
                org.javarosa.core.model.ItemsetBinding itemset = q.getDynamicChoices();
                boolean unseededRandom = itemset != null && itemset.randomize && itemset.randomSeedExpr == null;
                if (unseededRandom) {
                    choices.sort(java.util.Comparator.comparing(c -> String.valueOf(((Map<?, ?>) c).get("value"))));
                    e.put("choicesOrder", "unseededRandom");
                }
                e.put("choices", choices);
            }
        } else if (event == FormEntryController.EVENT_GROUP || event == FormEntryController.EVENT_REPEAT) {
            e.put("label", model.getCaptionPrompt().getLongText());
            e.put("appearance", model.getCaptionPrompt().getAppearanceHint());
        }
        return e;
    }

    // ---------------------------------------------------------------- helpers

    static void setUpReferences(File dir) {
        ReferenceManager manager = ReferenceManager.instance();
        manager.reset();
        for (String scheme : MEDIA_SCHEMES) manager.addReferenceFactory(new FileReferenceFactory(scheme, dir));
    }

    static final java.util.regex.Pattern UUID = java.util.regex.Pattern.compile(
        "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}");

    static final java.util.regex.Pattern DATE_TIME = java.util.regex.Pattern.compile(
        "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?");
    static final long RUN_STARTED = System.currentTimeMillis();

    /**
     * Makes traces deterministic (TRACE_FORMAT.md): generated UUIDs become
     * {@code <uuid>}, date-times taken during this run become {@code <now>}
     * and today's date becomes {@code <today>}.
     */
    static String normalize(String s) {
        if (s == null) return null;
        s = UUID.matcher(s).replaceAll("<uuid>");
        s = DATE_TIME.matcher(s).replaceAll(m -> isDuringRun(m.group()) ? "<now>" : m.group());
        return s.replace(java.time.LocalDate.now().toString(), "<today>");
    }

    static boolean isDuringRun(String isoDateTime) {
        try {
            java.time.temporal.TemporalAccessor t = java.time.format.DateTimeFormatter.ISO_DATE_TIME
                .parseBest(isoDateTime, java.time.OffsetDateTime::from, java.time.LocalDateTime::from);
            long millis = t instanceof java.time.OffsetDateTime o
                ? o.toInstant().toEpochMilli()
                : ((java.time.LocalDateTime) t).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli();
            return millis >= RUN_STARTED - 1_000 && millis <= System.currentTimeMillis() + 1_000;
        } catch (RuntimeException e) {
            return false;
        }
    }

    static String ref(TreeReference reference) {
        return reference.toString(true);
    }

    static Map<String, Object> error(Throwable t) {
        while (t.getCause() != null && t.getMessage() == null) t = t.getCause();
        Map<String, Object> e = new LinkedHashMap<>();
        e.put("type", t.getClass().getSimpleName());
        e.put("message", t.getMessage());
        return e;
    }

    static Map<Integer, String> constantNames(String prefix) {
        Map<Integer, String> names = new HashMap<>();
        for (Field f : Constants.class.getFields()) {
            if (Modifier.isStatic(f.getModifiers()) && f.getType() == int.class && f.getName().startsWith(prefix)) {
                try {
                    names.putIfAbsent(f.getInt(null), camel(f.getName().substring(prefix.length())));
                } catch (IllegalAccessException ignored) {
                }
            }
        }
        return names;
    }

    /** {@code SELECT_ONE} → {@code selectOne}, matching DartRosa enum names. */
    static String camel(String upper) {
        StringBuilder sb = new StringBuilder();
        boolean up = false;
        for (char c : upper.toLowerCase().toCharArray()) {
            if (c == '_') { up = true; continue; }
            sb.append(up ? Character.toUpperCase(c) : c);
            up = false;
        }
        return sb.toString();
    }

    static void print(Object trace) throws Exception {
        System.out.println(JSON.writeValueAsString(trace));
    }

    static void write(Path file, Object trace) throws Exception {
        Files.createDirectories(file.getParent());
        Files.writeString(file, JSON.writeValueAsString(trace) + "\n");
    }
}
