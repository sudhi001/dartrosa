# Licensing and compliance

DartRosa is licensed under the [Apache License, Version 2.0](../../LICENSE)
(SPDX: `Apache-2.0`). It is a Dart translation of
[JavaRosa](https://github.com/getodk/javarosa) and parts of
[ODK Collect](https://github.com/getodk/collect), both Apache-2.0, so it
is a derivative work of those projects; [NOTICE.md](../../NOTICE.md)
credits them and every other third-party component.

This page covers what that means for users, which third-party code and
data the repository contains, and how the project keeps its compliance
artifacts up to date. It is not legal advice.

## Using and redistributing DartRosa

You can use, modify and redistribute DartRosa, commercially or not, under
the Apache License 2.0. When you redistribute it (as source, or compiled
into an app):

1. **Include the license.** Ship a copy of the Apache License 2.0
   (`LICENSE`).
2. **Keep the notices.** Ship the `NOTICE` file of each DartRosa package
   you use (`packages/<name>/NOTICE`; [NOTICE.md](../../NOTICE.md) for the
   whole repository), for example in your app's "open source licenses"
   screen. Flutter's `showLicensePage` lists the `LICENSE` files of your
   dependencies but not their `NOTICE` files: add them with
   `LicenseRegistry.addLicense`.
3. **Keep source notices.** Keep the copyright and SPDX headers at the top
   of the source files.
4. **State your changes.** If you modify DartRosa files, add a notice
   saying so to the files you changed.
5. **Dependencies.** The packages DartRosa depends on have their own
   (permissive) licenses, listed [below](#dependencies). Pub and Flutter's
   license page include their `LICENSE` files.

The packages name no trademark of the upstream projects except to describe
where the code comes from; "ODK" is used only in that descriptive sense.

## What is in this repository

| Path | License | Copyright |
|---|---|---|
| Everything not listed below | Apache-2.0 | The DartRosa Authors ([AUTHORS](../../AUTHORS)) |
| Files whose header says "Derived from ..." | Apache-2.0 (Apache-2.0 AND MIT for files derived from myanmar-calendar) | The DartRosa Authors and the upstream holders named in the header |
| `conformance/forms/javarosa/`, `packages/dartrosa_flutter/example/assets/forms/javarosa/` | Apache-2.0 | JavaRosa and contributors |
| `conformance/forms/collect/`, `packages/dartrosa_flutter/example/assets/forms/collect/`, `packages/dartrosa_encryption/tool/golden/forms/` | Apache-2.0 | ODK Collect contributors |
| `conformance/forms/webforms/` | Apache-2.0 | ODK Web Forms contributors |
| `conformance/forms/pyxform/` (except its README) | BSD-2-Clause | 2015 XLSForm |
| `packages/dartrosa_calendars/tool/oracle/src/org/odk/collect/.../MyanmarDateUtils.java` | Apache-2.0 | 2019 Nafundi (unmodified ODK Collect file) |

[REUSE.toml](../../REUSE.toml) records this table in machine-readable form,
and [LICENSES/](../../LICENSES) holds the full text of every license used
in the repository, named by SPDX identifier
([REUSE 3.x](https://reuse.software) layout). `reuse lint` passes.

### Third-party components

Code translated to Dart (DartRosa's SBOM records these as `DESCENDANT_OF`
relationships):

| Component | Version | License | Copyright | Translated into |
|---|---|---|---|---|
| [JavaRosa](https://github.com/getodk/javarosa) | v6.0.0 | Apache-2.0 | (C) 2009 JavaRosa; 2017-2019 Nafundi; 2022 ODK; contributors (JavaRosa NOTICE retained in NOTICE.md) | `dartrosa` (the engine), parts of `dartrosa_entities` |
| [ODK Collect](https://github.com/getodk/collect) | `master`, 2026 (the release using JavaRosa v6.0.0) | Apache-2.0 | (C) 2009-2017 University of Washington; 2016-2019 Nafundi; contributors | `dartrosa_calendars`, `dartrosa_collect`, `dartrosa_encryption`, `dartrosa_entities`, `dartrosa_external_data`, `dartrosa_openrosa`, parts of `dartrosa_flutter` |
| [opencsv](https://opencsv.sourceforge.net/) | 5.12.0 | Apache-2.0 | 2005 Bytecode Pty Ltd. | `dartrosa_collect`, `dartrosa_external_data` (CSV reader) |
| [Joda-Time](https://www.joda.org/joda-time/) | 2.14.0 | Apache-2.0 | 2001-2015 Stephen Colebourne (Joda-Time NOTICE retained) | `dartrosa_calendars` (Coptic, Ethiopic, Islamic chronologies) |
| [persianjodatime](https://github.com/mohamadian/persianjodatime) | 1.2 | Apache-2.0 | none stated | `dartrosa_calendars` (Persian chronology) |
| [bikram-sambat](https://github.com/medic/bikram-sambat) | 1.8.1 | Apache-2.0 | none stated (Medic) | `dartrosa_calendars` (Bikram Sambat) |
| [myanmar-calendar (mmcalendar)](https://github.com/chanmratekoko/mmcalendar), after [mcal](https://github.com/yan9a/mcal) | 1.1.1.RELEASE | MIT | (c) 2017 Chan Mrate Ko Ko; (c) 2018 Yan Naing Aye | `dartrosa_calendars` (Myanmar calendar) |

Test data used unmodified:

| Component | Version | License | Copyright | Where |
|---|---|---|---|---|
| JavaRosa test resources | v6.0.0 | Apache-2.0 | JavaRosa contributors | `conformance/forms/javarosa/`, Flutter example assets |
| ODK Collect test forms | `test-forms/src/main/resources` | Apache-2.0 | ODK Collect contributors | `conformance/forms/collect/`, Flutter example assets, `dartrosa_encryption` golden fixtures |
| ODK Web Forms fixtures | commit 4389b656 | Apache-2.0 | ODK Web Forms contributors | `conformance/forms/webforms/` |
| pyxform test-suite XLSForms and their XForms | 4.5.0, commit 5dc3a39f | BSD-2-Clause | (c) 2015 XLSForm | `conformance/forms/pyxform/` |

Tools that run JVM libraries to produce test vectors
(`conformance/jvm_oracle/`, `packages/dartrosa_calendars/tool/oracle/`,
`packages/dartrosa_encryption/tool/golden/`) download those libraries at
run time (`deps.txt`); none is redistributed in the repository.

### Dependencies

Runtime dependencies of the DartRosa packages, as resolved when
[sbom.spdx.json](sbom.spdx.json) was generated (dev-only dependencies such
as `test`, `lints` and `analyzer` are not distributed and not listed). All
are permissive licenses compatible with Apache-2.0; none is copyleft.

| Package | Version | License | Copyright | Used by |
|---|---|---|---|---|
| args | 2.7.0 | BSD-3-Clause | 2013, the Dart project authors | transitive (xml 7) |
| async | 2.13.1 | BSD-3-Clause | 2015, the Dart project authors | transitive |
| characters | 1.4.1 | BSD-3-Clause | 2019, the Dart project authors | transitive (Flutter) |
| clock | 1.1.3 | Apache-2.0 | Google Inc. (AUTHORS); no NOTICE file | dartrosa, dartrosa_openrosa |
| collection | 1.19.1 | BSD-3-Clause | 2015, the Dart project authors | dartrosa, dartrosa_entities, dartrosa_external_data, dartrosa_openrosa |
| convert | 3.1.2 | BSD-3-Clause | 2015, the Dart project authors | transitive |
| crypto | 3.0.7 | BSD-3-Clause | 2015, the Dart project authors | dartrosa, dartrosa_collect, dartrosa_encryption, dartrosa_external_data, dartrosa_openrosa |
| flutter (SDK) | SDK | BSD-3-Clause | 2014 The Flutter Authors | dartrosa_flutter |
| flutter_svg | 2.3.0 | MIT | (c) 2018 Dan Field | dartrosa_flutter |
| http | 1.6.0 | BSD-3-Clause | 2014, the Dart project authors | dartrosa_openrosa |
| http_parser | 4.1.2 | BSD-3-Clause | 2014, the Dart project authors | transitive |
| intl | 0.20.3 | BSD-3-Clause | 2013, the Dart project authors | dartrosa, dartrosa_flutter |
| logging | 1.3.0 | BSD-3-Clause | 2013, the Dart project authors | dartrosa, dartrosa_external_data, dartrosa_openrosa |
| material_color_utilities | 0.13.0 | Apache-2.0 | 2021 Google LLC; no NOTICE file | transitive (Flutter) |
| meta | 1.19.0 | BSD-3-Clause | 2016, the Dart project authors | dartrosa, dartrosa_calendars, dartrosa_encryption, dartrosa_entities, dartrosa_openrosa |
| mime | 2.1.0 | BSD-3-Clause | 2015, the Dart project authors | dartrosa_openrosa |
| path | 1.9.1 | BSD-3-Clause | 2014, the Dart project authors | transitive |
| path_parsing | 1.1.0 | MIT | (c) 2018 Dan Field | dartrosa_flutter |
| petitparser | 7.1.0 | MIT | (c) 2006-2026 Lukas Renggli | transitive (xml) |
| pinenacl | 0.6.0 | MIT | (c) 2018 Pal Dorogi | dartrosa (`extract-signed`) |
| pointycastle | 4.0.0 | MIT | (c) 2000-2019 The Legion of the Bouncy Castle Inc. | dartrosa_encryption |
| sky_engine (SDK) | SDK | various (Flutter engine; see its LICENSE) | Flutter engine authors and bundled projects | transitive (Flutter) |
| source_span | 1.10.2 | BSD-3-Clause | 2014, the Dart project authors | transitive |
| string_scanner | 1.4.1 | BSD-3-Clause | 2014, the Dart project authors | transitive |
| term_glyph | 1.2.2 | BSD-3-Clause | 2017, the Dart project authors | transitive |
| typed_data | 1.4.0 | BSD-3-Clause | 2015, the Dart project authors | transitive |
| vector_graphics, vector_graphics_codec, vector_graphics_compiler | 1.2.3, 1.1.13, 1.3.0 | BSD-3-Clause | 2013 The Flutter Authors | transitive (flutter_svg) |
| vector_math | 2.4.3 | BSD-3-Clause | 2013 The Flutter Authors | transitive (Flutter) |
| web | 1.1.1 | BSD-3-Clause | 2023, the Dart project authors | transitive |
| xml | 7.1.0 (6.6.1 in dartrosa_flutter) | MIT | (c) 2006-2026 Lukas Renggli | dartrosa, dartrosa_openrosa, dartrosa_flutter |

### Dependency lock files

Following the [Dart guidance](https://dart.dev/tools/pub/private-files),
library packages don't commit `pubspec.lock`, so CI tests them against the
newest versions their constraints allow, as their users get them. The
workspace root only holds library packages, so its lock file is not
committed (`.gitignore`); neither is `packages/dartrosa_flutter`'s.
`packages/dartrosa_flutter/example` is an application, so its
`pubspec.lock` is committed. The SBOM records the versions resolved when
it was generated.

### Test keys

`packages/dartrosa_encryption/tool/golden/test_private_key.pem` is a
**test-only RSA key**, published on purpose so that the encryption golden
fixtures can be reproduced (see the
[README there](../../packages/dartrosa_encryption/tool/golden/README.md)).
It protects nothing; secret scanners can ignore it, and it must never be
used for real data.

## Compliance artifacts and how to regenerate them

| Artifact | What it is | How it is produced |
|---|---|---|
| `LICENSE`, `packages/*/LICENSE` | Canonical Apache-2.0 text (identical files) | Copy of `LICENSES/Apache-2.0.txt` |
| `NOTICE.md`, `packages/*/NOTICE` | Attribution notices (Apache-2.0 section 4(d)); each package's `NOTICE` covers the code it contains, for when it is distributed on its own | Maintained by hand when third-party code is added |
| `AUTHORS` | Who "The DartRosa Authors" are | Contributors add themselves |
| `LICENSES/`, `REUSE.toml` | License texts and bulk annotations (REUSE 3.x) | By hand; check with `reuse lint` |
| SPDX file headers (ISO/IEC 5962) | `// Copyright <year> The DartRosa Authors`, a `Derived from <project> (<classes>), <copyright>; modified: translated to Dart.` line for ported files (Apache-2.0 section 4(b)), and `// SPDX-License-Identifier: <license>` | `dart run tool/license_headers.dart` |
| [sbom.spdx.json](sbom.spdx.json) | SPDX 2.3 SBOM: DartRosa packages, runtime dependencies with licenses and checksums, upstream projects | `dart run tool/generate_sbom.dart` |

Headers:

```sh
dart run tool/license_headers.dart --check     # exit 1 if a file lacks one
dart run tool/license_headers.dart --apply     # add missing headers
# Optional: take the "Derived from" copyright lines from the upstream files
dart run tool/license_headers.dart --apply \
  --upstream javarosa=../javarosa --upstream collect=../collect
```

The tool covers every tracked `.dart`, `.java`, `.sh` and `.py` file except
generated files (marked `GENERATED`/`Do not edit`), test vectors, the
conformance forms and traces, example assets and unmodified upstream files.
A file counts as ported when a comment says `Port of ...`; the project is
the one the comment names, or the one the package ports. `--apply` never
rewrites an existing header, so a header can be corrected by hand.

SBOM:

```sh
dart pub get
(cd packages/dartrosa_flutter && flutter pub get)
dart run tool/generate_sbom.dart           # rewrite docs/legal/sbom.spdx.json
dart run tool/generate_sbom.dart --check   # exit 1 if it is out of date
```

## OpenChain (ISO/IEC 5230) alignment

DartRosa's open source compliance process is **aligned with** ISO/IEC
5230:2020 (OpenChain); the project has not been certified or audited
against it.

- **Policy.** DartRosa is distributed under Apache-2.0. Inbound code, data
  and dependencies must be under a license compatible with redistribution
  under Apache-2.0: permissive licenses (Apache-2.0, MIT, BSD-2-Clause,
  BSD-3-Clause, ISC, Zlib, CC0-1.0 or similar) are accepted; copyleft
  (GPL, LGPL, AGPL, MPL, EPL, CDDL), non-commercial, "no license" and
  unknown-license material is not.
- **Roles.** The maintainers (see [AUTHORS](../../AUTHORS)) are the
  compliance contacts: they review every change that adds third-party
  code, data or dependencies, and answer compliance questions through the
  [issue tracker](https://github.com/sudhi001/dartrosa/issues).
- **Adding a dependency.** Check its license (read its `LICENSE`; pana
  and pub.dev show the detected license) against the policy, then
  regenerate the SBOM and update the dependency table above.
- **Adding third-party code (porting) or data.** Check the upstream license
  and copyright lines; record the source (project, version or commit,
  path) in a `Port of ...` comment; add the attribution and any upstream
  `NOTICE` text to `NOTICE.md` and the `NOTICE` of each package that
  contains it; add the license text to `LICENSES/` and, for files that
  can't carry a header, an entry to `REUSE.toml`; run
  `tool/license_headers.dart --apply` and `tool/generate_sbom.dart`.
- **Artifacts for each release.** Before publishing, check `LICENSE`, the
  `NOTICE` files, `tool/license_headers.dart --check`,
  `tool/generate_sbom.dart --check` and `reuse lint`; the two tool checks
  are cheap enough to run on every CI build.
- **Awareness.** This page is the project's compliance documentation;
  contributors adding code, data or dependencies follow the steps above.
