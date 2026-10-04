# pyxform-generated XForms

Generated with **pyxform 4.5.0** (https://github.com/XLSForm/pyxform, commit
5dc3a39f, BSD-2-Clause) from XLSForms in its test suite. The XForms are
pyxform output, unmodified.

- `example_forms/`, `bug_example_forms/`: `xls2xform --pretty_print` of the
  XLSForms in `tests/fixtures/example_forms` and
  `tests/fixtures/bug_example_forms` (`.xlsx`/`.xlsm`; `.csv`/`.md` copies
  that convert to identical XForms are omitted). `itemsets.csv` is pyxform
  output; `fruits.csv` is the fixture used by `pull_data.xml`.
- `tests/<module>/<test>.xml`: the markdown XLSForms embedded in pyxform's
  unit tests (`assertPyxformXform(md=...)`), converted with
  `pyxform.xls2xform.convert(pretty_print=True, form_name="test_name")`. The
  markdown source is kept next to each form as `<test>.md` (forms built from
  `ss_structure` dicts have none). From the 924 distinct XForms the test suite
  produces, a subset was kept: per test module, the largest form of up to
  six test functions (about one in five); forms referencing external
  `jr://file*` data files that the tests do not ship, and generated
  performance forms over 60 kB, were left out.

Not converted: `bad_calc.xlsx`, `duplicate_columns.xlsx`,
`xl_date_ambiguous.xlsx` (pyxform rejects them), `fruits.csv` (a data file,
not an XLSForm), `UCL_Biomass_Plot_Form.xlsx` (needs five CSV files that are
not in pyxform's repository).
