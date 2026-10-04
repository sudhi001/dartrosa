<!-- pyxform tests/test_translations.py::TestTranslations::test_translation_detection__survey_columns_present_with_media -->
        | survey  |                |       |            |            |           |
        |         | type           | name  | label      | label::en  | image::en |
        |         | select_one c0  | f     | f          |            |           |
        |         | select_one c1  | q1    | Question 1 | Question A | c1.png    |
        | choices |           |      |        |            |           |
        |         | list name | name | label  | label::en  | label::fr | audio::de |
        |         | c0        | n    | l      |            |           |           |
        |         | c1        | na   | la     |            |           |           |
        |         | c1        | nb   | lb     | lb-e       |           | c1_nb.mp3 |
        |         | c1        | nc   | lc     | lc-e       | lc-f      | c1_nc.mp3 |
        
