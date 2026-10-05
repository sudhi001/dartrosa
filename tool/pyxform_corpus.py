# Copyright 2026 The DartRosa Authors
# SPDX-License-Identifier: Apache-2.0

"""Regenerates conformance/forms/pyxform/tests from pyxform's test suite.

Usage (pyxform checkout with `pip install -e .[dev] pytest` in a venv):

    cd pyxform
    CAPTURE_OUT=/tmp/capture PYTHONPATH=<dartrosa>/tool:. \
        python -m pytest -q -p pyxform_corpus tests
    python <dartrosa>/tool/pyxform_corpus.py /tmp/capture \
        <dartrosa>/conformance/forms/pyxform/tests

As a pytest plugin it records the XForm of every markdown/ss_structure
XLSForm a test expects to convert; as a script it keeps, per test module,
the largest form of up to six test functions (about one in five), skipping
forms with external jr://file* instances and forms over 60 kB.
"""
import glob
import hashlib
import json
import math
import os
import re
import shutil
import sys


def _install_capture():
    from tests import pyxform_test_case as ptc
    from pyxform.xls2xform import convert

    out = os.environ["CAPTURE_OUT"]
    os.makedirs(out, exist_ok=True)
    original = ptc.PyxformTestCase.assertPyxformXform

    def patched(self, *args, **kw):
        md, ss = kw.get("md"), kw.get("ss_structure")
        if (md or ss) and not kw.get("errored") and not kw.get("odk_validate_error__contains"):
            try:
                xml = convert(xlsform=md or ss, pretty_print=True,
                              form_name=kw.get("name") or "test_name",
                              warnings=[], file_type=".md").xform
            except Exception:
                xml = None
            if xml:
                sha = hashlib.sha1(xml.encode()).hexdigest()[:10]
                test = os.environ.get("PYTEST_CURRENT_TEST", "x").split(" ")[0]
                with open(os.path.join(out, sha + ".xml"), "w") as f:
                    f.write(xml)
                with open(os.path.join(out, sha + ".json"), "w") as f:
                    json.dump({"test": test, "sha": sha, "md": md}, f)
        return original(self, *args, **kw)

    ptc.PyxformTestCase.assertPyxformXform = patched


def select(capture, dest):
    modules = {}
    for path in sorted(glob.glob(os.path.join(capture, "*.json"))):
        record = json.load(open(path))
        xml = open(path[:-5] + ".xml").read()
        if len(xml) > 60000:
            continue
        if any(not s.startswith("jr://instance") for s in re.findall(r'src="(jr://[^"]+)"', xml)):
            continue
        module = record["test"].split("::")[0]
        function = record["test"].split("::")[-1].split("[")[0]
        best = modules.setdefault(module, {}).get(function)
        if best is None or len(xml) > best[0]:
            modules[module][function] = (len(xml), record["sha"], record["test"])
    for module, functions in sorted(modules.items()):
        chosen = sorted(functions.values(), reverse=True)
        for _, sha, test in chosen[:min(6, max(1, math.ceil(len(chosen) / 5)))]:
            name = os.path.basename(module)[:-3]
            function = test.split("::")[-1].split("[")[0]
            os.makedirs(os.path.join(dest, name), exist_ok=True)
            shutil.copy(os.path.join(capture, sha + ".xml"), os.path.join(dest, name, function + ".xml"))
            md = json.load(open(os.path.join(capture, sha + ".json")))["md"]
            if md:
                with open(os.path.join(dest, name, function + ".md"), "w") as f:
                    f.write(f"<!-- pyxform {test} -->\n" + md.strip("\n") + "\n")


if __name__ == "__main__":
    select(sys.argv[1], sys.argv[2])
elif "CAPTURE_OUT" in os.environ:
    _install_capture()
