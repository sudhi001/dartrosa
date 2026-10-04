<!-- pyxform tests/test_group.py::TestGroupOutput::test_table_list_appearance -->
        | survey  |
        | | type          | name | label | hint       | appearance |
        | | begin_group   | g1   | G1    |            | table-list |
        | | select_one c1 | q1   | Q1    | first row! |            |
        | | select_one c1 | q2   | Q2    |            |            |
        | | end_group     |      |       |            |            |

        | choices |
        | | list_name | name | label |
        | | c1        | n1   | N1    |
        
