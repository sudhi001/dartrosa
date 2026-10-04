<!-- pyxform tests/test_group.py::TestGroupParsing::test_names__group_same_as_repeat_in_same_context_in_repeat__case_insensitive_warning -->
        | survey |
        | | type          | name | label |
        | | begin repeat  | r1   | R1    |
        | | begin repeat  | g2   | G2    |
        | | text          | q1   | Q1    |
        | | end repeat    |      |       |
        | | begin group   | G2   | G2    |
        | | text          | q2   | Q2    |
        | | end group     |      |       |
        | | end repeat    |      |       |
        
