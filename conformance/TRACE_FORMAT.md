# Conformance trace format (v1)

**Audience:** contributors changing the engine or the oracle. **Type:**
reference. The overall flow is drawn in
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md#how-correctness-is-checked).

The JVM oracle (`jvm_oracle/`, real JavaRosa 6.0.0) and DartRosa both turn a
form plus a scenario into a JSON **trace**. CI compares the two; any difference
is a DartRosa bug (or a documented, intentional deviation).

## Inputs

**Forms** live in `forms/` (`forms/javarosa/` is imported from JavaRosa's
test resources by `tool/import_javarosa_forms.sh`; `forms/dartrosa/` is ours;
`forms/collect/`, `forms/webforms/` and `forms/pyxform/` come from ODK
Collect, ODK Web Forms and pyxform; their licences are listed in
[docs/legal/README.md](../docs/legal/README.md)).
`jr://file/…`, `jr://file-csv/…`, `jr://images/…`, `jr://audio/…` and
`jr://video/…` resolve to the form's own directory.

**Scenarios** live in `scenarios/*.scenario.json`:

```json
{
  "description": "free text",
  "form": "forms/dartrosa/basics.xml",
  "steps": [ { "op": "answer", "ref": "/data/age", "value": "30" } ]
}
```

`form` is relative to the conformance root (the directory containing
`forms/`). Every form without a scenario is traced with the default scenario
`[walk, validate]`.

### Operations

| `op` | Fields | Behaviour (JavaRosa API) |
|---|---|---|
| `walk` | — | Jump to beginning, then `stepToNextEvent()` until end of form, recording every event. Repeat prompts are passed, not accepted. |
| `next` / `prev` | — | `stepToNextEvent()` / `stepToPreviousEvent()`, records the event. |
| `jumpToBeginning` | — | Jump to the beginning-of-form index. |
| `answer` | `ref`, `value` | `answerQuestion(index, data, midSurvey=true)`. `value` is the XML string form, parsed for the question's data type with `XFormAnswerDataParser` (select multiple: space-separated). `null`/`""` clears. The repeat instance in `ref` must already exist. |
| `addRepeat` | `ref` (no final predicate, e.g. `/data/child`) | Appends one repeat instance (`Scenario.createNewRepeat`). |
| `removeRepeat` | `ref` (e.g. `/data/child[2]`) | Deletes that repeat instance. |
| `setLanguage` | `language` | `setLanguage(language)`. |
| `validate` | — | `FormDef.validate()` (whole-form revalidation as on finalize). |

## Output

```jsonc
{
  "traceVersion": 1,
  "form": "forms/dartrosa/basics.xml",
  "parse": { "ok": true, "title": "Basics", "languages": [], "language": null },
  // or { "ok": false, "error": { "type": "...", "message": "..." } } and nothing else
  "steps": [ /* one result per input step, see below */ ],
  "instance": "<?xml …?><data …>…</data>"   // submission XML after all steps
}
```

Step results always echo `op`; on failure they carry
`"error": { "type", "message" }` instead of their normal fields.

| `op` | Result fields |
|---|---|
| `walk` | `events`: list of events |
| `next` / `prev` | `event` |
| `answer` | `result`: `accepted` \| `required` \| `constraintViolated` |
| `validate` | `outcome`: `ok` \| `required` \| `constraintViolated`; `ref` of the first failing question or `null` |
| others | — |

### Events

| Field | When | Value |
|---|---|---|
| `event` | always | `beginningOfForm`, `endOfForm`, `promptNewRepeat`, `question`, `group`, `repeat`, `repeatJuncture` |
| `ref` | not at beginning/end | 1-based reference, `TreeReference.toString(true)` (e.g. `/data/child[2]/name[1]`; the first step has no predicate) |
| `label`, `appearance` | question, group, repeat | long label text in the current language; appearance hint |
| `control` | question | DartRosa `ControlType` name (`input`, `selectOne`, `selectMulti`, `rank`, `range`, `upload`, `trigger`, `imageChoose`, …) |
| `dataType` | question | DartRosa `DataType` name (`text`, `integer`, `decimal`, `date`, `choice`, `choiceList`, `geopoint`, …) |
| `hint`, `required`, `readonly`, `value` | question | hint text; booleans; answer as its XML string or `null` |
| `choices` | select one / multiple / rank | `[{ "value", "label" }]` in display order |
| `choicesOrder` | unseeded `randomize()` | `"unseededRandom"`; `choices` are then sorted by value |

## Structure traces (`traces/structure/`)

For every form the oracle also dumps the parsed form itself, before any
engine work (`Structure.java`; DartRosa: `test/conformance/structure_dump.dart`,
checked by `test/conformance/structure_test.dart`):

- `title`, `name`, `languages`, `defaultLanguage`;
- `elements`: the control tree (kind, ref, control type, appearance,
  label/textId, hint fields, static choices, itemset references and filter,
  repeat count/noAddRemove, additional attributes, children);
- `instance` and `secondaryInstances`: every node's name, multiplicity,
  data type, value, relevant/required/enabled/repeatable flags, namespace
  and prefix, preload, constraint, attributes and bind attributes;
- `triggerables`: kind, expression, contexts, sorted targets and triggers
  (sorted by kind/expression/context, because JavaRosa keeps them in a
  `HashSet`);
- `outputs`, default `submission`, and parse `warnings`.

## Init traces (`traces/init/`)

For every form: `parse` (with the error for failures; cycle node lines
sorted, because JavaRosa lists them in identity-hash order), `cascades`
(each triggerable's immediate cascades, by sort key), `initialize` (ok or
the error) and `instance` (as in structure traces) after
`FormDef.initialize(newInstance = true)`. When initialization fails, only
the error is compared: what JavaRosa evaluated before failing depends on
its identity-hash order. Checked by `test/conformance/init_test.dart`.

## DAG traces (`traces/dag/`)

`scenarios/**.dag.json` scripts drive the form directly after
initialization: `setValue {ref, value}`, `createRepeat {ref}`,
`deleteRepeat {ref}`, `constraint {ref, value}` (result recorded),
`repeatRelevant {ref}` (result recorded) and `postProcess`. Each step
records its result or error and the main instance. Repeat creation and
deletion replay `FormDef.createNewRepeat` / `deleteRepeat` after their
`FormIndex`-to-reference step. Checked by
`test/conformance/dag_scenario_test.dart`.

Init and DAG traces contain local date-times, so the Dart comparisons run
only when the process time zone is UTC (as the oracle's is). The same holds
for structure traces of forms whose instance has a time or date-time
default (parsing converts it to the local zone).

## Fuzz traces (`traces/fuzz/`)

For every form and each seed in `FUZZ_SEEDS` (11, 22, 33): a seeded random
walk (`FuzzWalk.java`, mirrored by `test/conformance/fuzz_test.dart`). A
Park–Miller generator picks, for each writable question, an empty answer
(1 in 10) or type-valid random text (choices sorted by value, so unseeded
`randomize()` doesn't matter), which each engine parses with its answer
parser and submits through `answerQuestion`; at "add another?" prompts it
adds up to three repeat instances. Each step records the event (as in walk
traces), the answer text, the result and the value afterwards; then the
validation outcome and the serialized instance. At most 400 steps.

## Normalization (both sides must apply it)

So that traces are byte-identical across runs and machines:

1. Run in time zone **UTC**.
2. Every UUID (`8-4-4-4-12` hex) → `<uuid>`.
3. Every ISO date-time taken while the trace was being produced → `<now>`.
4. Today's date (`yyyy-MM-dd`) → `<today>`.
5. Unseeded random choice lists are sorted (see `choicesOrder`).
6. JSON objects have their keys sorted; output is pretty-printed.

Rules 2–4 apply to answer values, labels, hints, choice labels and the
serialized instance.

## Comparing

- `parse.ok` must match. When both fail, only `ok` must match; error type
  and message are informational, because JavaRosa sometimes fails with internal
  errors (e.g. `NullPointerException`) where DartRosa raises
  `FormParseException`.
- Everything else must be identical, including step `error` presence.
- Intentional deviations are listed in `conformance/DEVIATIONS.md` with a
  reason and the affected traces.
