# Compatibility

What DartRosa supports, compared with ODK JavaRosa 6.0.0 (the engine of
ODK Collect) and ODK Collect itself. The reference is the
[ODK XForms spec](https://getodk.github.io/xforms-spec/); where JavaRosa
departs from the spec, DartRosa follows JavaRosa.

Columns:

- **Engine**: `dartrosa` (parsing, recalculation, validation, navigation,
  serialization).
- **Collect packages**: the Collect-layer package that adds the feature
  (`dartrosa_collect`, `dartrosa_entities`, `dartrosa_external_data`,
  `dartrosa_encryption`, `dartrosa_openrosa`, `dartrosa_calendars`).
- **Flutter**: `dartrosa_flutter`, the Material renderer.

Legend: **yes** = supported; **delegate** = the renderer calls an
`XFormDelegates` method the app implements (without one, the value can be
typed); **app** = the engine exposes it and the app decides what to do;
**n/a** = not applicable to that layer; **no** = not supported.

## Conformance evidence

| | |
|---|---|
| Conformance corpus | 401 XForms in `conformance/forms` (JavaRosa 65, ODK Collect 119, ODK Web Forms 77, pyxform 132, DartRosa 8), counted as the `.xml` and `.xhtml` files with an `h:html` root; the other `.xml` files are secondary instances |
| Oracle traces | 397 forms traced by real JavaRosa 6.0.0 (`conformance/jvm_oracle`): structure, initialization and full walks, 397 each; 1,191 seeded random-answer (fuzz) walks; DAG scenario traces. The other 4 forms are listed in `conformance/nondeterministic.txt` (unseeded `random()`, `decimal-date-time(now())`, and a JavaRosa error message that depends on Java identity-hash order) |
| Result | 0 diffs: the Dart replay (`packages/dartrosa/test/conformance`) matches every trace, including byte-identical submission XML. CI regenerates the traces with JavaRosa and fails if they change |
| JavaRosa unit tests | Every JavaRosa 6.0.0 test class in the port map (PORTING_PLAN §10.5) is ported (`packages/dartrosa/test`, 133 test files; each ported file says "Port of JavaRosa v6.0.0 \<Class\>"). Tests of dropped subjects (`ExternalizableTest`, `BufferedInputStreamTests`) are replaced by tests of the replacement (`FormDefCodec`) |
| Intentional deviations | Listed in [`conformance/DEVIATIONS.md`](../conformance/DEVIATIONS.md) (e.g. `regex()` uses the ECMAScript dialect, unknown `property()` names give `''`); none affects the corpus traces |
| Renderer | The example app (`packages/dartrosa_flutter/example/test/corpus_test.dart`, run in CI) fills, saves, resumes, edits, finalizes, encrypts and exports every corpus form; forms JavaRosa or Collect reject are reported with the reason |

## Platforms

| Platform | Status | How it is checked |
|---|---|---|
| Dart VM (JIT) | yes | CI: `dart test packages/dartrosa` in 9 time zones (UTC, America/New_York, Asia/Kolkata, Europe/London, Etc/GMT-2, Etc/GMT-3, Pacific/Chatham, Europe/Warsaw, Europe/Kiev); Collect packages in UTC and America/New_York |
| Dart AOT (`dart compile exe`, Flutter release on Android/iOS/desktop) | yes | Benchmarks are run AOT ([BENCHMARKS.md](BENCHMARKS.md)); no reflection or `dart:mirrors` anywhere |
| Web, dart2js | yes | CI: `dart test -p chrome` for all 7 workspace packages |
| Web, dart2wasm | yes | CI: `dart test -p chrome --compiler dart2wasm` for all 7 workspace packages |
| Flutter (Android, iOS, web, desktop) | yes | CI: `flutter analyze` and widget tests of `dartrosa_flutter`; the example app's corpus test. Golden tests are rendered on macOS and excluded from CI |

The engine and Collect packages are pure Dart: no Flutter, no `dart:io`
(`tool/check_core_purity.dart`, run in CI). `dart:io` access (files, form
media) is the app's job, through a `ResourceResolver`.

Platform notes:

- **Integers on the web.** Web `int`s are JavaScript doubles (53 bits of
  precision); `long` values beyond ±2^53 lose precision there.
- **Time zones.** Like JavaRosa (device default zone), DartRosa uses the
  process's local zone; Dart can't change it at runtime, so JavaRosa tests
  that call `TimeZone.setDefault` run only under a matching `TZ`.
- **Regular expressions.** `regex()` uses Dart's `RegExp` (ECMAScript),
  anchored to the whole string; Java-only syntax (possessive quantifiers,
  atomic groups, `\p{Alpha}` POSIX classes, `\Q…\E`) is rejected.

## XForm structure

| Feature | Engine | Collect packages | Flutter | Notes |
|---|---|---|---|---|
| `h:html`/`h:head`/`h:title`/`h:body`, XForms/`jr`/`odk`/`orx`/`entities` and user namespaces | yes | | n/a | Namespaces kept in the submission |
| `<model>` attributes: `odk:xforms-version`, `entities:entities-version`, `version`, `id` | yes | | n/a | `version()` reads the form version |
| Primary instance (elements and attributes as data nodes) | yes | | yes | Attribute binds (`/data/item/@id`) included |
| Repeat templates: `jr:template` and implicit (first instance) | yes | | yes | |
| `<itext>` translations, `default="true()"` | yes | | yes | Language picker is the app's; `XFormView` follows `session.language` |
| Multiple binds on one nodeset | yes | | n/a | Merge rules as JavaRosa |
| `<submission>`: `action`, `method`, `base64RsaPublicKey`, `orx:auto-send`, `orx:auto-delete` | yes | `dartrosa_encryption`, `dartrosa_openrosa` | app | |
| Parse warnings (unknown elements/attributes, deprecated events) | yes | | n/a | |
| Form-definition cache | yes | | n/a | `FormDefCodec` (versioned, keyed by form hash; not JavaRosa's `Externalizable` format) |
| Compact and SMS serializers | yes | | n/a | `CompactSerializingVisitor`, `SMSSerializingVisitor` |

## Body controls

| Control | Engine (`ControlType`) | Flutter | Notes |
|---|---|---|---|
| `input` (text, numbers, dates, geo, barcode by type) | `input` | yes | |
| `textarea` | `textarea` | yes | |
| `secret` | `secret` | yes | Masked field |
| `select1` | `selectOne` | yes | See appearances below |
| `select` | `selectMulti` | yes | |
| `odk:rank` | `rank` | yes | Reorderable list |
| `range` (`start`/`end`/`step`, `odk:tick-interval`, `odk:tick-labelset`, `odk:placeholder`) | `range` | yes | |
| `upload` image/audio/video/file | `imageChoose`, `audioCapture`, `videoCapture`, `fileCapture`, `upload` | delegate | `XFormDelegates.captureMedia` gets the media type and appearance |
| `upload` OSM (`osm/*`, `odk:tag`) | `osmCapture` | delegate | Via `captureMedia` with `osm/*` |
| `trigger` | `trigger` | yes | Acknowledge |
| Note (read-only text input) | `input` + readonly (`QuestionNode.isNote`) | yes | |
| Standalone `label`, `submit`, untyped | `label`, `submit`, `untyped` | default widget | Represented for parity; not used by ODK tools |
| `group` (with/without `ref`), nested | yes | yes | Card; `field-list` = one pager screen |
| `repeat` (`nodeset`, `jr:count`, `jr:noAddRemove`), nested | yes | yes | Add/remove, "add another?" prompt in pager mode |
| Repeat captions (`jr:addCaption`, `entryHeader`, …) | yes | yes | `RepeatInstanceNode.header` |
| `<label>`, `<hint>`, guidance hint, `<output value>` | yes | yes | Guidance shown per `XFormView.guidanceHints` |
| `<item>`, `<itemset>` (incl. `jr:itext` labels, `randomize`, `seed`) | yes | yes | Seeded order identical to Collect (Park–Miller + Fisher–Yates) |
| Choice media (image, audio, video, big-image) | yes | partial | Images through `delegates.image(uri)` |
| Unknown control/bind attributes | yes | app | `QuestionNode.attributes`, `QuestionNode.bindAttributes` |

## Bind attributes

| Attribute | Engine | Flutter | Notes |
|---|---|---|---|
| `type` | yes | yes | |
| `relevant`, `readonly`, `required`, `constraint`, `calculate` | yes | yes | Non-relevance and readonly inherit to descendants |
| `jr:constraintMsg`, `jr:requiredMsg` (literal or `jr:itext`) | yes | yes | Shown inline; `AnswerConstraintViolated.message`, `AnswerRequired.message` |
| `jr:preload`, `jr:preloadParams` | yes | n/a | See preloads |
| `saveIncomplete` | yes | app | `QuestionNode.saveIncomplete`; the app saves a draft |
| `orx:max-pixels` | kept as bind attribute | app | Not applied by the renderer; the capture delegate can read it |
| `odk:length`, `entities:saveto`, `odk:allow-mock-accuracy`, other namespaced | kept | app / `dartrosa_entities` (`saveto`) | |

## Data types

| Type | Engine (`DataType` / `AnswerValue`) | Flutter |
|---|---|---|
| `string` | `text` / `StringValue` | yes |
| `int`, `integer` | `integer` / `IntegerValue` | yes |
| `long` | `long` / `LongValue` | yes |
| `decimal`, `double`, `float` | `decimal` / `DecimalValue` | yes |
| `boolean` | `boolean` / `BooleanValue` | yes |
| `date` | `date` / `DateValue` | yes |
| `time` | `time` / `TimeValue` | yes |
| `dateTime` | `dateTime` / `DateTimeValue` | yes |
| `gYear`, `gMonth`, `gDay`, `gYearMonth`, `gMonthDay` | mapped as JavaRosa does | yes |
| `select1`, `select` | `choice` / `SelectOneValue`, `multipleItems` / `SelectMultiValue` | yes |
| `geopoint`, `geotrace`, `geoshape` | `GeoPointValue`, `GeoTraceValue`, `GeoShapeValue` | delegate |
| `barcode` | `barcode` / `StringValue` | delegate |
| `binary`, `base64Binary`, `hexBinary`, `anyURI` | `binary` / `StringValue`, `PointerValue` | delegate |
| Text answers (`UncastValue`) | read as the question type; unreadable text, wrong types and unknown choices give `AnswerRejected` | yes |

## XPath

The full XPath 1.0 syntax ODK uses: absolute and relative paths, `.`,
`..`, `*`, `@attr`, multiple and nested predicates, filter expressions,
unions, all operators, `instance('id')`, `current()`. Axes, coercions,
comparison semantics, number formatting (Java `Double.toString`) and error
types (`XPathArityException`, `XPathTypeMismatchException`,
`XPathUnhandledException`, `XPathUnsupportedException`,
`XPathMissingInstanceException`, `XPathSyntaxException`) match JavaRosa.

### Functions

Every function JavaRosa 6.0.0 implements is built into the engine
(`packages/dartrosa/lib/src/xpath/functions.dart`, plus the form-level
`jr:itext` and `jr:choice-name` handlers):

| Group | Functions |
|---|---|
| Boolean / node | `true` `false` `boolean` `not` `if` `coalesce` `count` `count-non-empty` `position` `instance` `current` `depend` `boolean-from-string` `checklist` `weighted-checklist` `once` |
| Number / math | `number` `int` `round` (1 or 2 args) `abs` `pow` `exp` `exp10` `log` `log10` `sqrt` `sin` `cos` `tan` `asin` `acos` `atan` `atan2` `pi` `min` `max` `sum` `random` |
| String | `string` `concat` `join` `substr` `substring-before` `substring-after` `contains` `starts-with` `ends-with` `string-length` `normalize-space` `translate` `regex` `uuid` (0 or 1 arg) `digest` (MD5, SHA-1, SHA-256, SHA-384, SHA-512; base64/hex) `base64-decode` `extract-signed` (Ed25519) |
| Select | `selected` `is-selected` `selected-at` `count-selected` `jr:choice-name` `randomize` (1 or 2 args) |
| Date / time | `today` `now` `date` `date-time` `decimal-date-time` `decimal-time` `format-date` `format-date-time` |
| Geo | `area` `enclosed-area` `distance` `geofence` |
| Repeat | `indexed-repeat` |
| Device / form | `property` `version` |
| Itext | `jr:itext` |
| Collect-provided | `pulldata` (`dartrosa_external_data` over CSV media; `dartrosa_entities` over entity lists, consulted first) |
| Custom | any `XPathFunctionHandler` in `DartRosaConfig.functions` (see [PLUGINS.md](PLUGINS.md)) |

Functions JavaRosa does **not** implement — `floor`, `ceiling`, `last`,
`local-name`, `name`, `substring`, `lang`, `id` and any unknown name —
raise `XPathUnhandledException`, exactly as in JavaRosa and Collect. Add
them as custom functions if a form needs them.

`format-date` month and day names (`%b`, `%a`) default to US English
(`en_US`, the oracle's locale); JavaRosa uses the JVM default locale.

## Recalculation, validation, navigation

| Feature | Engine | Flutter | Notes |
|---|---|---|---|
| Dependency graph (relevant, readonly, required, calculate), topological order, cycle errors | yes | n/a | Cycle messages match JavaRosa |
| Recompute on answer, repeat add/delete, language change | yes | yes | Widgets rebuild per question |
| Constraint check on answer; `required` on navigation and finalize | yes | yes | Pager validates the screen before moving on |
| Whole-form validation on finalize (first failure) | yes | yes | `FinalizeFailure.failure`; the renderer shows the error on the first failing question |
| Predicate filter strategies (equality index, comparison and idempotent caches) | yes | n/a | Results identical to JavaRosa's |
| Choice filters, cascading selects, clearing answers no longer offered | yes | yes | |
| Navigation events (questions, groups, repeat prompts, `jr:count`, `noAddRemove`) | yes (`FormNavigator`) | yes (pager) | |
| Constraint range hints (`requestConstraintHint`) | yes | no | Engine only |
| Debug evaluation events | yes | n/a | `FormSession.changes` |

## Secondary instances

| Kind | Engine | Collect packages | Notes |
|---|---|---|---|
| Inline `<instance id>` | yes | | |
| XML file (`jr://file/x.xml`) | yes | | Read through the `ResourceResolver` |
| CSV (`jr://file-csv/x.csv`) | yes | | Header row, quoting, BOM |
| GeoJSON (`jr://file/x.geojson`) | yes | | Features → items with ODK geo strings |
| Last saved (`jr://instance/last-saved`) | yes (`DartRosaConfig.lastSavedSrc`) | `dartrosa_collect` (`LastSaved`, wired by `collectFormConfig`) | Empty without a source |
| Entity lists | via instance providers | `dartrosa_entities` (`withEntities`) | Local lists stand in for `jr://file-csv/<list>.csv` unless the form has the file attached |
| Custom providers / parsers | yes (`ExternalInstanceParser`) | | |
| Missing instance | `XPathMissingInstanceException` when referenced | | As JavaRosa |

## Actions and events

| Feature | Engine | Flutter | Notes |
|---|---|---|---|
| Events `odk-instance-first-load`, `odk-instance-load`, `xforms-ready`, `odk-new-repeat`, `jr-insert`, `xforms-value-changed`, `xforms-revalidate` | yes | n/a | Deprecated aliases supported with a parse warning |
| `setvalue` (top-level and nested) | yes | n/a | |
| `odk:setgeopoint` | yes (stub; `DartRosaConfig.setGeopointAction` for a real location) | app | |
| `odk:recordaudio` | yes (`RecordAudioAction`, listener per form) | app | Background recording is the app's |

## Preloads (`jr:preload`)

| Preload | Engine | Notes |
|---|---|---|
| `timestamp` `start` / `end` | yes | `end` set at finalize |
| `date` `today` | yes | |
| `property` (`deviceid`, `subscriberid`, `simserial`, `phonenumber`, `username`, `email`) | yes | From `DartRosaConfig.properties` (`PropertyManager`) |
| `uid` | yes | `uuid:` prefix |
| Custom `PreloadHandler`s | yes | `DartRosaConfig.preloadHandlers` |
| `meta/deprecatedID` on edit | | `dartrosa_collect` (`EditedFormFinalizationProcessor`) |

## Localization (itext forms)

| Feature | Engine | Flutter |
|---|---|---|
| Languages list, default language, runtime switch | yes | yes |
| Text forms: long, `short`, `image`, `big-image`, `audio`, `video`, `guidance` | yes (`LocalizedText`) | text, image, guidance; audio/video through delegates |
| Fallbacks (missing form/language) | yes | yes |
| Constraint/required messages per language | yes | yes |
| ODK markdown subset (`*em*`, `**strong**`, `#`, links, `<span style>`) | passthrough | yes |
| Right-to-left forms (ar, fa, he, ur, ps, sd, ug, yi, dv) | n/a | yes |
| UI chrome strings | n/a | English `XFormLocalizations`; apps add other languages |

## Collect-layer features

| Feature | Package | Flutter | Notes |
|---|---|---|---|
| `pulldata()` over CSV media | `dartrosa_external_data` (`ExternalDataPlugin`) | yes | |
| `search()` appearance (`contains`, `matches`, `startsWith`, `endsWith`) | `dartrosa_external_data` | yes | Missing CSV shows Collect's warning |
| Fast external itemsets (`itemsets.csv` with a select's `query`) | `dartrosa_collect` | app | `loadItemsetChoices` |
| Entities: create / update / upsert, `entities:saveto`, labels, entity lists as instances, `pulldata()` on lists, offline updates, server integrity checks | `dartrosa_entities` (+ `dartrosa_openrosa` for integrity URLs) | n/a | `withEntities`, `formEntities`, `saveFormEntities` |
| Encrypted submissions (RSA + AES, `submission.xml` manifest, signature) | `dartrosa_encryption` | n/a | Decryptable by ODK Central and Briefcase |
| Audit log (`meta/audit`, `odk:location-*`, `odk:track-changes`, `odk:identify-user`, `odk:track-changes-reasons`) | `dartrosa_collect` (`FormAudit`) | app | The example app wires `FormAudit` around `XFormView` |
| Edited submissions (`meta/deprecatedID`) | `dartrosa_collect` | n/a | |
| Last-saved instance | `dartrosa_collect` | n/a | |
| OpenRosa form list, manifests, downloads, multipart submission, Digest/Basic auth | `dartrosa_openrosa` | n/a | Over `package:http` (VM and web) |
| Non-Gregorian calendars | `dartrosa_calendars` | yes | See date appearances |
| External apps (`ex:`, group `intent`) | n/a | delegate | Parameters evaluated as Collect's `ExternalAppsUtils` |
| XLSForm → XForm conversion | not provided | | Use pyxform, XLSForm Online or ODK Central |

## Collect appearances (Flutter renderer)

Appearances are passed through by the engine verbatim
(`FormNode.appearance`); the renderer interprets them. Unsupported
appearances fall back to the default widget with one `debugPrint` per
appearance. Any widget can be replaced with `widgetOverrides`.

| Control | Supported appearances | Not supported |
|---|---|---|
| text | `multiline`, `numbers`, `masked` (and `secret`), `ex:`, `printer` / `printer:…`, `url` | |
| integer / decimal / long | `thousands-sep`, `ex:`, `counter` (integer), `bearing` (decimal, from `compassBearing`) | |
| date | pickers; `no-calendar`, `month-year`, `year`; `ethiopian`, `coptic`, `islamic`, `bikram-sambat`, `myanmar`, `persian`, `buddhist` (spinner dialog from `dartrosa_calendars`, stores the Gregorian date) | |
| time / dateTime | pickers | |
| select one | radio list, `minimal`, `quick`, `autocomplete`, `columns`, `columns-N`, `columns-pack`, `no-buttons`, `likert`, `label`, `list-nolabel`, `list`, `image-map`, `map` (delegate), `search(…)`; old names `compact`, `quickcompact`, `compact-N`, `horizontal`, `horizontal-compact`, `search` | |
| select multiple | check boxes, `minimal`, `autocomplete`, `columns*`, `no-buttons`, `label`, `list-nolabel`, `list`, `image-map`, `search(…)` | `map` |
| rank | reorderable list | |
| range | slider, `vertical`, `picker`, `rating`, `no-ticks` | |
| geopoint / geotrace / geoshape | location via delegate; `maps`, `placement-map` (on the app's map when `canShowMaps`), `hidden-answer` | accuracy thresholds (`accuracyThreshold`, `unacceptableAccuracyThreshold`) not enforced by the renderer |
| image | capture via delegate | `signature`, `draw`, `annotate`, `new`, `new-front`, `selfie` are passed to `captureMedia` but not handled by the renderer itself (they produce the unsupported-appearance debug print); `orx:max-pixels` not applied |
| audio / video / file | capture via delegate | `new`, `new-front`, `quality` (same as above) |
| barcode | scanner via delegate | `front` (passed through only) |
| trigger, note | acknowledge, read-only text | |
| group | card, `field-list`, `table-list`, `intent` attribute | |
| repeat | add/remove, "add another?" prompt, `noAddRemove`, `jr:count` | |
| width hints | `w1`…`wN` accepted and ignored | |

## Known gaps

- **Renderer**: no built-in camera, location, barcode, audio or map
  implementations — they are `XFormDelegates` methods the app implements
  (a separate plugins package is planned). Image/audio capture
  appearances, geopoint accuracy thresholds and `orx:max-pixels` are left
  to the delegate. Multi-select `map` is not supported. Constraint range
  hints are not shown. The `dartrosa_flutter` README's appearance table
  predates calendar support (calendars are supported, see above).
- **Engine**: `regex()` dialect is ECMAScript, not Java; `long` precision
  on the web is 53 bits; date names default to `en_US`.
- **Open plan items** ([PORTING_PLAN.md §15](PORTING_PLAN.md)): not every
  §7/§8 checklist row links a test yet; the full JavaRosa test suite has
  not been confirmed green on Chrome/WASM for every class; pana 160/160
  and the benchmark targets are not yet signed off (growing a repeat to
  1,000 instances is about 1.5× slower than JavaRosa, see
  [BENCHMARKS.md](BENCHMARKS.md)).
- **Not provided**: XLSForm conversion; a `dart:io` resource resolver
  package (apps implement `ResourceResolver` on their storage).
