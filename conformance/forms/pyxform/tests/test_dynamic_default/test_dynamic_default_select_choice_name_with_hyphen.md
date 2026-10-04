<!-- pyxform tests/test_dynamic_default.py::TestDynamicDefault::test_dynamic_default_select_choice_name_with_hyphen -->
        | survey  |               |      |         |         |
        |         | type          | name | label   | default |
        |         | select_one c1 | q1   | Select1 | a-2     |
        |         | select_one c2 | q2   | Select2 | 1-1     |
        |         | select_one c3 | q3   | Select3 | a-b     |
        | choices |           |      |       |
        |         | list_name | name | label |
        |         | c1        | a-1  | C A-1 |
        |         | c1        | a-2  | C A-2 |
        |         | c2        | 1-1  | C 1-1 |
        |         | c2        | 2-2  | C 1-2 |
        |         | c3        | a-b  | C A-B |
        
