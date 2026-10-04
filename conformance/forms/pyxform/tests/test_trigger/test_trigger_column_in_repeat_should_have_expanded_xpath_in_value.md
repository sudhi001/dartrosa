<!-- pyxform tests/test_trigger.py::TriggerSetvalueTests::test_trigger_column_in_repeat_should_have_expanded_xpath_in_value -->
            | survey |              |       |                        |                        |         |
            |        | type         | name  | label                  | calculation            | trigger |
            |        | begin repeat | rep   |                        |                        |         |
            |        | dateTime     | one   | Enter text             |                        |         |
            |        | dateTime     | three | Enter text (triggered) | string-length(${one})  | ${one}  |
            |        | end repeat   |       |                        |                        |         |
            
