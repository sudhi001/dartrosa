<!-- pyxform tests/test_dynamic_default.py::TestDynamicDefault::test_dynamic_default_in_repeat_nested_in_repeat -->
        | survey |              |      |       |         |
        |        | type         | name | label | default |
        |        | begin repeat | r1   |       |         |
        |        | date         | q0   | Date  | now()   |
        |        | integer      | q1   | Foo   |         |
        |        | begin repeat | r2   |       |         |
        |        | integer      | q2   | Bar   | ${q1}   |
        |        | end repeat   | r2   |       |         |
        |        | end repeat   | r1   |       |         |
        
