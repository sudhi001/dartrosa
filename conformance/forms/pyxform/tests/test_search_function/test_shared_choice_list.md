<!-- pyxform tests/test_search_function.py::TestTranslations::test_shared_choice_list -->
        | survey  |               |       |            |           |                   |
        |         | type          | name  | label::en  | label::fr | appearance        |
        |         | select_one c1 | q1    | Question 1 | Chose 1   | search('my_file') |
        |         | select_one c1 | q2    | Question 2 | Chose 2   | search('my_file', 'matches', 'filtercol', 'x1') |
        | choices |               |       |           |           |
        |         | list_name     | name  | label::en | label::fr |
        |         | c1            | id    | label_en  | label_fr  |
        
