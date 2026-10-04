<!-- pyxform tests/test_translations.py::TestTranslationsOrOther::test_specify_other__with_translations__with_nested_repeat -->
        | survey  |                        |       |            |            |
        |         | type                   | name  | label      | label::eng |
        |         | begin group            | g1    | Group 1    | Group 1    |
        |         | begin repeat           | r1    | Repeat 1   | Repeat 1   |
        |         | select_one c1 or_other | q1    | Question 1 | Question A |
        |         | end repeat             | r1    |            |            |
        |         | end group              | g1    |            |            |
        | choices |           |      |       |            |           |
        |         | list name | name | label | label::eng | label::fr |
        |         | c1        | na   | la    | la-e       | la-f      |
        |         | c1        | nb   | lb    | lb-e       |           |
        
