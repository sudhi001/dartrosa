<!-- pyxform tests/test_bind_conversions.py::BindConversionsTest::test_bind_required_message_with_reference -->
            | survey |       |      |       |            |                    |
            |        | type  | name | label | required   | required_message |
            |        | int   | foo  | foo   |            |                    |
            |        | text  | text | text  | true()     | required, ${foo}   |
            
