<!-- pyxform tests/test_trigger.py::TriggerSetvalueTests::test_trigger_with_trigger_of_type_select_nests_setvalue_in_select -->
            | survey |                    |      |             |                    |         |
            |        | type               | name | label       | calculation        | trigger |
            |        | select_one choices | a    | Some choice |                    |         |
            |        | integer            | b    |             | string-length(${a})| ${a}    |
            | choices|                    |      |             |                    |         |
            |        | list_name          | name | label       |
            |        | choices            | a    | A           |
            |        | choices            | aa   | AA          |
            
