<!-- pyxform tests/test_xls2json.py::TestXLS2JSONSheetNameHeuristics::test_workbook_to_json__multiple_misspellings__all_ok -->
            | survey   |                        |           |       |               |
            |          | type                   | name      | label | choice_filter |
            |          | select_one l1          | q1        | Q1    |               |
            |          | select_one_external l2 | q2        | Q2    | q1=${q1}      |
            | choices  |               |           |       |
            |          | list_name     | name      | label |
            |          | l1            | 1         | C1    |
            | external_choices |               |           |       |
            |                  | list_name     | name      | q1    |
            |                  | l2            | 1         | 1     |
            |                  | l2            | 2         | 2     |
            | settings |               |           |       |
            |          | id_string     | title     |
            |          | my_id         | My Survey |
            
