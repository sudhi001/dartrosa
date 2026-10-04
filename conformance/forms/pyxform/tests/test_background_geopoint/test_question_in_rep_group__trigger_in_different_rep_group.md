<!-- pyxform tests/test_background_geopoint.py::TestBackgroundGeopointOutput::test_question_in_rep_group__trigger_in_different_rep_group -->
        | survey |
        |        | type                | name     | label      | trigger |
        |        | begin_repeat        | groupA   |            |         |
        |        | integer             | temp     | Enter temp |         |
        |        | end_repeat          |          |            |         |
        |        | begin_repeat        | groupB   |            |         |
        |        | background-geopoint | temp_geo |            | ${temp} |
        |        | end_repeat          |          |            |         |
        
