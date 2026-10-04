<!-- pyxform tests/test_last_saved.py::LastSavedTest::test_multiple_last_saved_in_calculate -->
            | survey |            |          |       |                                       |
            |        | type       | name     | label | calculation                           |
            |        | integer    | foo      | Foo   |                                       |
            |        | integer    | bar      | Bar   |                                       |
            |        | calculate  | last-sum |       | ${last-saved#foo} + ${last-saved#bar} |
            
