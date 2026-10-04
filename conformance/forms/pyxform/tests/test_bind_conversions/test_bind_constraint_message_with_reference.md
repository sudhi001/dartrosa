<!-- pyxform tests/test_bind_conversions.py::BindConversionsTest::test_bind_constraint_message_with_reference -->
            | survey |       |      |       |                      |                    |
            |        | type  | name | label | constraint           | constraint_message |
            |        | int   | foo  | foo   |                      |                    |
            |        | text  | text | text  | string-length(.) > 1 | too short ${foo}   |
            
