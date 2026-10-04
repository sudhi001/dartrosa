<!-- pyxform tests/test_fields.py::TestQuestionParsing::test_names__question_same_as_group_in_same_context_in_repeat__case_insensitive_warning -->
        | survey |
        | | type         | name | label |
        | | begin repeat | r1   | R1    |
        | | text         | q1   | Q1    |
        | | begin group  | Q1   | G2    |
        | | text         | q2   | Q2    |
        | | end group    |      |       |
        | | end repeat   |      |       |
        
