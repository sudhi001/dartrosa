<!-- pyxform tests/test_search_function.py::TestTranslations::test_usage_with_other_selects -->
        | survey  |               |       |            |           |                   |
        |         | type          | name  | label::en  | label::fr | appearance        |
        |         | select_one c1 | q1    | Question 1 | Chose 1   | search('my_file') |
        |         | select_one c2 | q2    | Question 2 | Chose 2   |                   |
        | choices |               |       |            |           |
        |         | list_name     | name  | label::en | label::fr |
        |         | c1            | id    | label_en  | label_fr  |
        |         | c2            | na    | la-e      | la-f      |
        |         | c2            | nb    | lb-e      | lb-f      |
        
