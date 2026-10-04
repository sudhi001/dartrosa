<!-- pyxform tests/test_repeat.py::TestRepeatOutput::test_repeat_using_select_uses_current_with_reference_path_in_predicate_and_instance_is_not_first_expression -->
        | survey |                 |              |                                                |               |                                                                               |
        |        | type            | name         | label                                          | choice_filter | calculation                                                                   |
        |        | begin repeat    | item-repeat  | Item                                           |               |                                                                               |
        |        | calculate       | item-counter |                                                |               | position(..)                                                                  |
        |        | calculate       | item         |                                                |               | ${item-counter} + instance('item')/root/item[itemindex=${item-counter}]/label |
        |        | begin group     | item-info    | Item info                                      |               |                                                                               |
        |        | note            | item-note    | All the following questions are about ${item}. |               |                                                                               |
        |        | select one item | stock-item   | Do you stock this item?                        | true()        |                                                                               |
        |        | end group       | item-info    |                                                |               |                                                                               |
        |        | end repeat      |              |                                                |               |                                                                               |
        | choices |           |                  |                   |           |
        |         | list_name | name             | label             | itemindex |
        |         | item      | gasoline-regular | Gasoline, Regular | 1         |
        |         | item      | gasoline-premium | Gasoline, Premium | 2         |
        |         | item      | gasoline-diesel  | Gasoline, Diesel  | 3         |
        
