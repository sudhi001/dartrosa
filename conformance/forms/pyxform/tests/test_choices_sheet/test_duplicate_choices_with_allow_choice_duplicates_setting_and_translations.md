<!-- pyxform tests/test_choices_sheet.py::TestChoicesSheet::test_duplicate_choices_with_allow_choice_duplicates_setting_and_translations -->
            | survey  |                 |      |       |
            |         | type            | name | label::en | label::ko |
            |         | select_one list | S1   | s1        | 질문 1     |
            | choices |                 |      |                |
            |         | list name       | name | label::en      | label::ko |
            |         | list            | a    | Pass           | 패스       |
            |         | list            | b    | Fail           | 실패       |
            |         | list            | c    | Skipped        | 건너뛴     |
            |         | list            | c    | Not Applicable | 해당 없음  |
            | settings |                |                         |
            |          | id_string      | allow_choice_duplicates |
            |          | Duplicates     | Yes                     |
            
