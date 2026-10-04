<!-- pyxform tests/test_last_saved.py::LastSavedTest::test_last_saved_in_repeat -->
            | survey |              |           |       |                            |
            |        | type         | name      | label | calculation                |
            |        | begin repeat | my-repeat |       |                            |
            |        | integer      | foo       | Foo   |                            |
            |        | calculate    | bar       |       | ${foo} + ${last-saved#foo} |
            |        | end repeat   | my-repeat |       |                            |
            |        | calculate    | baz       |       | ${foo} + ${last-saved#foo} |
            
