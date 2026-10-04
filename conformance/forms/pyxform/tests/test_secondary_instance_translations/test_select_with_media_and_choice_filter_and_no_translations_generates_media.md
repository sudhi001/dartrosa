<!-- pyxform tests/test_secondary_instance_translations.py::TestSecondaryInstanceTest::test_select_with_media_and_choice_filter_and_no_translations_generates_media -->
        | survey |                    |                 |                                 |                           |
        |        | type               | name            | label                           | choice_filter             |
        |        | select_one consent | consent         | Would you like to participate ? |                           |
        |        | select_one mood    | enumerator_mood | How are you feeling today ?     | selected(${consent}, 'y') |
        | choices |
        |         | list_name | name | label | media::image |
        |         | mood      | h    | Happy | happy.jpg    |
        |         | mood      | s    | Sad   | sad.jpg      |
        |         | consent   | y    | Yes   |              |
        |         | consent   | n    | No    |              |
        
