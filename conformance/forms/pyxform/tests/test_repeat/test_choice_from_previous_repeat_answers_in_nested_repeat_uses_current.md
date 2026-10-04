<!-- pyxform tests/test_repeat.py::TestRepeatOutput::test_choice_from_previous_repeat_answers_in_nested_repeat_uses_current -->
        | survey  |                    |                           |                                                |                             |
        |         | type               | name                      | label                                          | choice_filter               |
        |         | text               | enumerators_name          | Enter enumerators name                         |                             |
        |         | begin repeat       | household_rep             | Household Repeat                               |                             |
        |         | integer            | household_id              | Enter household ID                             |                             |
        |         | begin repeat       | household_mem_rep         | Household member repeat                        |                             |
        |         | text               | name                      | Enter name of a household member               |                             |
        |         | integer            | age                       | Enter age of the household member              |                             |
        |         | end repeat         | household_mem_rep         |                                                |                             |
        |         | begin repeat       | selected                  | Select a representative                        |                             |
        |         | integer            | target_min_age            | Minimum age requirement                        |                             |
        |         | select one ${name} | selected_name             | Choose a name                                  | ${age} > ${target_min_age}  |
        |         | end repeat         | selected                  |                                                |                             |
        |         | end repeat         | household_rep             |                                                |                             |
        
