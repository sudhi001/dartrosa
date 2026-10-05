// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

package org.dartrosa.oracle;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.javarosa.core.model.Constants;
import org.javarosa.core.model.FormDef;
import org.javarosa.core.model.SelectChoice;
import org.javarosa.core.model.ValidateOutcome;
import org.javarosa.core.model.data.IAnswerData;
import org.javarosa.form.api.FormEntryController;
import org.javarosa.form.api.FormEntryModel;
import org.javarosa.form.api.FormEntryPrompt;
import org.javarosa.model.xform.XFormSerializingVisitor;
import org.javarosa.test.Scenario;
import org.javarosa.xform.util.XFormAnswerDataParser;

/**
 * Seeded random walk: answers every question with a type-valid random
 * value (as text, parsed by the engine's answer parser), adds repeat
 * instances at random, then validates and serializes. DartRosa's
 * test/conformance/fuzz_test.dart mirrors this generator exactly.
 */
final class FuzzWalk {
    private FuzzWalk() {}

    static final int MAX_STEPS = 400;

    /** Park-Miller minimal standard generator (31 bits). */
    static final class Rng {
        long state;
        Rng(long seed) { state = seed % 2147483647L; if (state <= 0) state += 2147483646L; }
        int next(int bound) {
            state = state * 16807L % 2147483647L;
            return (int) (state % bound);
        }
    }

    static final String[] WORDS = {"alpha", "beta", "gamma delta", "épsilon", "zeta & eta", "theta<iota>", "", "kappa'lambda", "mu\"nu", "123", "x y z"};

    static String answerText(Rng rng, int dataType, List<SelectChoice> choices) {
        switch (dataType) {
            case Constants.DATATYPE_INTEGER: return String.valueOf(rng.next(200) - 50);
            case Constants.DATATYPE_LONG: return String.valueOf(rng.next(100000) * 1000L);
            case Constants.DATATYPE_DECIMAL: return (rng.next(2000) - 500) + "." + rng.next(100);
            case Constants.DATATYPE_DATE: return "20" + (10 + rng.next(20)) + "-0" + (1 + rng.next(9)) + "-1" + rng.next(9);
            case Constants.DATATYPE_TIME: return "1" + rng.next(10) + ":3" + rng.next(10) + ":00.000Z";
            case Constants.DATATYPE_DATE_TIME: return "2021-0" + (1 + rng.next(9)) + "-1" + rng.next(9) + "T1" + rng.next(10) + ":2" + rng.next(10) + ":00.000Z";
            case Constants.DATATYPE_BOOLEAN: return rng.next(2) == 0 ? "true" : "false";
            case Constants.DATATYPE_GEOPOINT: return (rng.next(180) - 90) + "." + rng.next(1000) + " " + (rng.next(360) - 180) + "." + rng.next(1000) + " " + rng.next(500) + " " + rng.next(20);
            case Constants.DATATYPE_GEOTRACE:
            case Constants.DATATYPE_GEOSHAPE: {
                String p = rng.next(10) + " " + rng.next(10) + " 0 0";
                return p + ";" + rng.next(10) + " 1" + rng.next(10) + " 0 0;1" + rng.next(10) + " " + rng.next(10) + " 0 0;" + p;
            }
            case Constants.DATATYPE_CHOICE:
            case Constants.DATATYPE_MULTIPLE_ITEMS:
                if (choices == null || choices.isEmpty()) return "";
                // By value, so unseeded randomize() order doesn't matter.
                choices = new ArrayList<>(choices);
                choices.sort(java.util.Comparator.comparing(SelectChoice::getValue));
                if (dataType == Constants.DATATYPE_CHOICE) return choices.get(rng.next(choices.size())).getValue();
                {
                    StringBuilder b = new StringBuilder();
                    for (SelectChoice c : choices) {
                        if (rng.next(2) == 0) {
                            if (b.length() > 0) b.append(' ');
                            b.append(c.getValue());
                        }
                    }
                    return b.toString();
                }
            case Constants.DATATYPE_BINARY: return "file" + rng.next(100) + ".jpg";
            default: return WORDS[rng.next(WORDS.length)];
        }
    }

    static Map<String, Object> run(File form, String displayPath, int seed) {
        Map<String, Object> trace = new LinkedHashMap<>();
        trace.put("traceVersion", Oracle.TRACE_VERSION);
        trace.put("form", displayPath);
        trace.put("seed", seed);
        Scenario s;
        try {
            Oracle.setUpReferences(form.getAbsoluteFile().getParentFile());
            s = Scenario.init(form);
        } catch (Throwable t) {
            trace.put("parse", Map.of("ok", false, "error", Oracle.stableError(t)));
            return trace;
        }
        trace.put("parse", Map.of("ok", true));
        FormEntryController controller = s.getFormEntryController();
        FormEntryModel model = controller.getModel();
        Rng rng = new Rng(seed);
        List<Object> steps = new ArrayList<>();
        try {
            int event = FormEntryController.EVENT_BEGINNING_OF_FORM;
            int repeatsAdded = 0;
            while (event != FormEntryController.EVENT_END_OF_FORM && steps.size() < MAX_STEPS) {
                event = controller.stepToNextEvent();
                Map<String, Object> step = Oracle.describe(model, event);
                if (event == FormEntryController.EVENT_QUESTION) {
                    FormEntryPrompt p = model.getQuestionPrompt();
                    if (!p.isReadOnly()) {
                        boolean empty = rng.next(10) == 0;
                        String text = empty ? "" : answerText(rng, p.getDataType(), p.getSelectChoices());
                        step.put("answer", text);
                        IAnswerData data = text.isEmpty() ? null
                            : XFormAnswerDataParser.getAnswerData(text, p.getDataType(), p.getQuestion());
                        step.put("result", Oracle.answerResult(controller.answerQuestion(model.getFormIndex(), data, true)));
                        IAnswerData now = model.getQuestionPrompt().getAnswerValue();
                        step.put("after", now == null ? null : Oracle.normalize(now.uncast().getString()));
                    }
                } else if (event == FormEntryController.EVENT_PROMPT_NEW_REPEAT) {
                    boolean add = repeatsAdded < 3 && rng.next(2) == 0;
                    step.put("add", add);
                    if (add) {
                        controller.newRepeat();
                        repeatsAdded++;
                    }
                }
                steps.add(step);
            }
        } catch (Throwable t) {
            steps.add(Map.of("error", Oracle.stableError(t)));
        }
        trace.put("steps", steps);
        FormDef def = s.getFormDef();
        try {
            ValidateOutcome outcome = def.validate();
            trace.put("validate", outcome == null ? "ok"
                : Oracle.answerResult(outcome.outcome) + " " + Oracle.ref(outcome.failedPrompt.getReference()));
        } catch (Throwable t) {
            trace.put("validate", Map.of("error", Oracle.stableError(t)));
        }
        try {
            trace.put("instance", Oracle.normalize(new String(new XFormSerializingVisitor().serializeInstance(def.getInstance()), StandardCharsets.UTF_8)));
        } catch (Throwable t) {
            trace.put("instance", Map.of("error", Oracle.stableError(t)));
        }
        return trace;
    }
}
