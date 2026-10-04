<!-- pyxform tests/test_last_saved.py::LastSavedTest::test_last_saved_in_choice_filter_does_not_use_current_or_relative_ref -->
            | survey |                |          |       |                                        |
            |        | type           | name     | label | choice_filter                          |
            |        | begin repeat   | repeat   |       |                                        |
            |        | select_one foo | foo      | Foo   | not(selected(${last-saved#foo}, name)) |
            |        | select_one foo | bar      | Bar   | not(selected(${foo}, name))            |
            |        | end repeat     | repeat   |       |                                        |
            | choices|                |          |       |                                        |
            |        | list_name      | name     | label |                                        |
            |        | foo            | a        | A     |                                        |
            
