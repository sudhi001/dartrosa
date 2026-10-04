<!-- pyxform tests/test_fields.py::TestQuestionParsing::test_names__question_same_as_repeat_in_different_repeat_context__ok -->
        | survey |
        | | type         | name | label |
        | | text         | q1   | Q1    |
        | | begin repeat | r1   | R1    |
        | | begin repeat | q1   | G1    |
        | | text         | q2   | Q1    |
        | | end repeat   |      |       |
        | | end repeat   |      |       |
        
