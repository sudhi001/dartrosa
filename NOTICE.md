# NOTICE

```text
DartRosa
Copyright 2026 The DartRosa Authors (see AUTHORS)

This product is licensed under the Apache License, Version 2.0 (see
LICENSE). It is a Dart translation of the Apache-2.0 projects named below,
a derivative work under section 4 of that license: their files were
modified by translating them to Dart, and each translated source file says
so in its header ("Derived from ...").
```

## JavaRosa

packages/dartrosa (the engine) is a translation of JavaRosa v6.0.0
(https://github.com/getodk/javarosa), Copyright (C) 2009 JavaRosa,
Copyright 2017-2019 Nafundi, Copyright 2022 ODK and the JavaRosa
contributors, licensed under the Apache License, Version 2.0. JavaRosa's
NOTICE file follows, unmodified.

---

# JavaRosa Copyright (C) 1999-2009

## Contributing Organizations
* Cell-Life (http://cell-life.org)
* Dimagi (http://dimagi.com)

## Contributing Individuals
* Alfred Mukudu (Cell-Life)
* Brian DeRenzi (University of Washington)
* Carl Hartung (University of Washington, Google)
* Catherine Dunn (Dimagi)
* Clayton Sims (Dimagi)
* Cory Zue (Dimagi)
* Daniel Kayiwa (Makerere University)
* Daniel Myung (Dimagi)
* Drew Roos (Dimagi)
* Geoffrey Mimano (DataDyne)
* Jonathan Jackson (Dimagi)
* Juan Marcelo Tondato (Instedd)
* Julian Hulme (Cell-Life)
* Kieran Sharpey-Schafer (Cell-Life)
* Mark Gerard (Makerere University, Business Objects)
* Matthais Nuessler (OpenMRS GSoC)
* Melissa Loudon (University of Cape Town)
* Munier Parker (Cell-Life)     
* Munaf Sheikh (Cell-Life)
* Ndubisi Onuora (Massachusetts Institute of Technology)
* Rowena Luk (Dimagi)
* Simon Peter Muwanga (Makerere University)
* Thomas Routen (Things Prime)
* Thomas Smyth (Georgia Institute of Technology)
* Teddy Svoronos (Georgetown University)
* Vijay Umapathy (Massachusetts Institute of Technology)
* Yaw Anokwa (University of Washington, Google)

## Linked Libraries
* BlueCove (http://bluecove.org)
* Fast MD5 (http://twmacinta.com/myjava/fast_md5.php)
* J2ME Polish (http://j2mepolish.org)
* J2MEUnit (http://j2meunit.sourceforge.net)
* java-cup (http://www2.cs.tum.edu/projects/cup)
* kXML (http://kobjects.org/kxml)                 
* Mesh4X (http://code.google.com/p/mesh4x)
* MicroEmulator (http://microemu.org)
* PyAntTasks (http://code.google.com/p/pyanttasks) 
* regexp-me (http://code.google.com/p/regexp-me)
* UmlGraph (http://umlgraph.org)
* ZXing (http://code.google.com/p/zxing)

## Other Sources
* Java Examples in a Nutshell, 3rd Edition (http://oreilly.com/catalog/9780596006204)
* Sun Microsystems, Inc (SnapperMIDlet, FileBrowser, FileBrowseActivity, CameraCanvas)

## Notes
If you have contributed to JavaRosa and are not included this list, please issue a pull request.

---

## ODK Collect

packages/dartrosa_calendars, dartrosa_collect, dartrosa_encryption, dartrosa_entities, dartrosa_external_data, dartrosa_openrosa and parts of dartrosa_flutter translate code from ODK Collect
(https://github.com/getodk/collect), Copyright (C) 2009-2017 University of
Washington, Copyright 2016-2019 Nafundi and the ODK Collect contributors,
licensed under the Apache License, Version 2.0. ODK Collect ships no NOTICE
file.

## opencsv

packages/dartrosa_collect (`itemsets_csv_reader.dart`) and dartrosa_external_data (`csv_reader.dart`) translate parts of opencsv 5.12.0 (`CSVReader`, `CSVParser`;
https://opencsv.sourceforge.net/), Copyright 2005 Bytecode Pty Ltd.,
licensed under the Apache License, Version 2.0. opencsv 5.12.0 ships no
NOTICE file.

## Calendar libraries (dartrosa_calendars)

packages/dartrosa_calendars translates ODK Collect's non-Gregorian date
picker logic (above) and the calendar algorithms of the libraries Collect
uses for them:

* Joda-Time 2.14.0 (https://www.joda.org/joda-time/), Copyright 2001-2015
  Stephen Colebourne, Apache License 2.0: `BasicChronology`,
  `BasicFixedMonthChronology`, `CopticChronology`, `EthiopicChronology`,
  `IslamicChronology`. Joda-Time's NOTICE file:

    =============================================================================
    = NOTICE file corresponding to section 4d of the Apache License Version 2.0 =
    =============================================================================
    This product includes software developed by
    Joda.org (https://www.joda.org/).

* persianjodatime 1.2 (https://github.com/mohamadian/persianjodatime),
  Apache License 2.0 (its sources carry no copyright line):
  `PersianChronology`, `PersianChronologyKhayyamBorkowski`.
* bikram-sambat 1.8.1 (https://github.com/medic/bikram-sambat), by Medic,
  Apache License 2.0 (its LICENSE carries no copyright line): `BsCalendar`
  and its month-length table.
* myanmar-calendar (mmcalendar) 1.1.1.RELEASE
  (https://github.com/chanmratekoko/mmcalendar), Copyright (c) 2017 Chan
  Mrate Ko Ko, MIT License; itself a port of Yan Naing Aye's Myanmar
  calendar algorithm (https://github.com/yan9a/mcal), Copyright (c) 2018
  Yan Naing Aye, MIT License: the `MyanmarDateKernel`,
  `MyanmarYearConstants`, `MyanmarCalendarKernel`, `Thingyan` and
  `WesternDateKernel` algorithms and the Myanmar month names. The files
  translated from it are under Apache-2.0 AND MIT; the MIT License
  requires this notice:

    Copyright (c) 2017 Chan Mrate Ko Ko
    Copyright (c) 2018 Yan Naing Aye

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

packages/dartrosa_calendars/test/vectors/ is generated by running those libraries
(packages/dartrosa_calendars/tool/oracle/oracle.sh); tool/oracle/src/org/odk/collect/.../
MyanmarDateUtils.java is ODK Collect's file, unmodified, with its own
Apache-2.0 header (Copyright 2019 Nafundi).

## Conformance corpus

conformance/forms/ holds the test forms DartRosa is checked against, used
unmodified:

* javarosa/: JavaRosa v6.0.0 test resources (`src/test/resources`,
  copied by tool/import_javarosa_forms.sh), Apache License 2.0
  (attribution above).
* collect/: ODK Collect test forms and media
  (`test-forms/src/main/resources`), Apache License 2.0 (attribution
  above).
* webforms/: XForm fixtures and media from ODK Web Forms
  (https://github.com/getodk/web-forms, `packages/common/src/fixtures`,
  commit 4389b656), Copyright the ODK Web Forms contributors, Apache
  License 2.0 (ODK Web Forms has no NOTICE file). Fixtures byte-identical
  to forms already in conformance/forms/ were not copied.
* pyxform/: see below.
* dartrosa/: DartRosa's own forms.

conformance/traces/ is generated by running JavaRosa on those forms
(conformance/jvm_oracle/oracle.sh).

## pyxform test forms

conformance/forms/pyxform/ contains XForms generated by pyxform 4.5.0
(https://github.com/XLSForm/pyxform) from the XLSForms in its test suite
(see conformance/forms/pyxform/README.md), licensed under the BSD
2-Clause License:

    Copyright (c) 2015, XLSForm
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are
    met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
    IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
    TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
    TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
    LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
    NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
