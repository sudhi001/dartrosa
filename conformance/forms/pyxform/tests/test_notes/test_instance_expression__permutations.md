<!-- pyxform tests/test_notes.py::TestNotes::test_instance_expression__permutations -->
        | survey  |               |      |       |
        |         | type          | name | label |
        |         | select_one c1 | q1   | Q1    |
        |         | select_one c2 | q2   | Q2    |
        |         | text          | text | Text  |
        |         | note          | note | Text ${text} instance('c1')/root/item[name = ${q1}]/label instance("c1")/root/item[name = ${q1}]/label instance('c2')/root/item[contains(name, ${q2})]/label instance("c2")/root/item[contains("name", ${q2})]/label instance('c2')/root/item[contains("name", ${q2})]/label instance('c2')/root/item[contains(name, instance('c1')/root/item[name = ${q1}]/label)]/label instance("c2")/root/item[contains(name, instance("c1")/root/item[name = ${q1}]/label)]/label instance('c2')/root/item[contains(name, instance("c1")/root/item[name = ${q1}]/label)]/label instance('c1')/root/item[name = 'y']/label instance("c1")/root/item[name = "y"]/label instance("c1")/root/item[name = 'y']/label instance("c1")/root/item[name <> 1 and "<>&" = "1"]/label text |
        | choices |
        |         | list_name | name | label |
        |         | c1        | y    | Yes   |
        |         | c1        | n    | No    |
        |         | c2        | b    | Big   |
        |         | c2        | s    | Small |
        
