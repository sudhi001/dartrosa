<!-- pyxform tests/test_group.py::TestGroupParsing::test_names__group_same_as_group_in_different_repeat_context__ok -->
        | survey |
        | | type         | name | label |
        | | begin group  | g1   | G1    |
        | | text         | q1   | Q1    |
        | | end group    |      |       |
        | | begin repeat | r1   | R1    |
        | | begin group  | g1   | G1    |
        | | text         | q1   | Q1    |
        | | end group    |      |       |
        | | text         | q2   | Q2    |
        | | end repeat   |      |       |
        
