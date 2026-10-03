# Conformance trace format (v1)

The JVM oracle (`jvm_oracle/`, real JavaRosa 6.0.0) and DartRosa both turn a
form plus a scenario into a JSON **trace**. CI compares the two; any difference
is a DartRosa bug (or a documented, intentional deviation).

## Inputs

**Forms** live in `forms/` (`forms/javarosa/` is imported from JavaRosa's
test resources by `tool/import_javarosa_forms.sh`; `forms/dartrosa/` is ours).
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

## Normalization (both sides must apply it)

So that traces are byte-identical across runs and machines:

1. Run in time zone **UTC**.
2. Every UUID (`8-4-4-4-12` hex) → `<uuid>`.
3. Every ISO date-time taken while the trace was being produced → `<now>`.
4. Today's date (`yyyy-MM-dd`) → `<today>`.
5. Unseeded random choice lists are sorted (see `choicesOrder`).
6. JSON objects have their keys sorted; output is pretty-printed.

## Comparing

- `parse.ok` must match. When both fail, only `ok` must match; error type
  and message are informational, because JavaRosa sometimes fails with internal
  errors (e.g. `NullPointerException`) where DartRosa raises
  `FormParseException`.
- Everything else must be identical, including step `error` presence.
- Intentional deviations are listed in `conformance/DEVIATIONS.md` with a
  reason and the affected traces.
