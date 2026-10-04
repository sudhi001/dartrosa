<!-- pyxform tests/test_repeat.py::TestRepeatOutput::test_repeat_adding_template_and_instance_with_group -->
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
            |        | begin group  | group_a  | Group A   |
            |        | begin repeat | repeat_a | Section A |
            |        | begin repeat | repeat_b | Section B |
            |        | text         | e        | Text E    |
            |        | begin group  | group_b  | Group B   |
            |        | text         | f        | Text F    |
            |        | text         | g        | Text G    |
            |        | note         | h        | Note H    |
            |        | end group    |          |           |
            |        | note         | i        | Note I    |
            |        | end repeat   |          |           |
            |        | end repeat   |          |           |
            |        | end group    |          |           |
            
