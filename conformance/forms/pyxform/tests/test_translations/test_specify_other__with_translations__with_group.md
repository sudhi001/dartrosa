<!-- pyxform tests/test_translations.py::TestTranslationsOrOther::test_specify_other__with_translations__with_group -->
        | survey  |                        |       |            |            |
        |         | type                   | name  | label      | label::eng |
        |         | begin group            | g1    | Group 1    | Group 1    |
        |         | select_one c1 or_other | q1    | Question 1 | Question A |
        |         | end group              | g1    |            |            |
        | choices |           |      |       |            |           |
        |         | list name | name | label | label::eng | label::fr |
        |         | c1        | na   | la    |            |           |
        |         | c1        | nb   | lb    | lb-e       | lb-f      |
        
