<!-- pyxform tests/test_repeat.py::TestRepeatOutput::test_repeat_adding_template_and_instance -->
            | survey |              |          |           |
            |        | type         | name     | label     |
            |        | text         | aa       | Text AA   |
            |        | begin repeat | section  | Section   |
            |        | text         | a        | Text A    |
            |        | text         | b        | Text B    |
            |        | text         | c        | Text C    |
            |        | note         | d        | Note D    |
            |        | end repeat   |          |           |
            |        |              |          |           |
            |        | begin repeat | repeat_a | Section A |
            |        | begin repeat | repeat_b | Section B |
            |        | text         | e        | Text E    |
            |        | begin repeat | repeat_c | Section C |
            |        | text         | f        | Text F    |
            |        | end repeat   |          |           |
            |        | end repeat   |          |           |
            |        | text         | g        | Text G    |
            |        | begin repeat | repeat_d | Section D |
            |        | note         | h        | Note H    |
            |        | end repeat   |          |           |
            |        | note         | i        | Note I    |
            |        | end repeat   |          |           |
            
