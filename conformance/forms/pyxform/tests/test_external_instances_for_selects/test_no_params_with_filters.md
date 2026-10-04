<!-- pyxform tests/test_external_instances_for_selects.py::TestSelectOneExternal::test_no_params_with_filters -->
        | survey |                            |        |        |                                 |
        |        | type                       | name   | label  | choice_filter                   |
        |        | select_one state           | state  | State  |                                 |
        |        | select_one_external city   | city   | City   | state=${state}                  |
        |        | select_one_external suburb | suburb | Suburb | state=${state} and city=${city} |
        
      | choices |           |      |       |
      |         | list_name | name | label |
      |         | state     | nsw  | NSW   |
      |         | state     | vic  | VIC   |
      | external_choices |           |           |       |           |
      |                  | list_name | name      | state | city      |
      |                  | city      | Sydney    | nsw   |           |
      |                  | city      | Melbourne | vic   |           |
      |                  | suburb    | Balmain   | nsw   | sydney    |
      |                  | suburb    | Footscray | vic   | melbourne |
    
