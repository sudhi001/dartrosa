<!-- pyxform tests/test_secondary_instance_translations.py::TestSecondaryInstanceTest::test_select_with_choice_filter_and_translations_generates_single_translation -->
        | survey |                    |      |       |               |
        |        | type               | name | label | choice_filter |
        |        | select_one list    | foo  | Foo   | name != ''    |
        | choices |
        |         | list_name | name | label | image | label::French |
        |         | list      | a    | A     | a.jpg | Ah            |
        |         | list      | b    | B     | b.jpg | Bé            |
        |         | list      | c    | C     | c.jpg | Cé            |
        
