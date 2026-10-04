<!-- pyxform tests/test_translations.py::TestTranslations::test_missing_translation__one_lang_all_cols -->
        | survey |               |      |       |            |            |                    |                   |                   |                   |                         |                       |
        |        | type          | name | label | label::eng | hint::eng  | guidance_hint::eng | media::image::eng | media::video::eng | media::audio::eng | constraint_message::eng | required_message::eng |
        |        | select_one c1 | q1   | hello | hi there   | salutation | greeting           | greeting.jpg      | greeting.mkv      | greeting.mp3      | check me                | mandatory             |
        | choices |           |      |                 |
        |         | list name | name | label | label::eng | media::audio::eng | media::image::eng | media::video::eng |
        |         | c1        | na   | la-d  | la-e       | la-d.mp3          | la-d.jpg          | la-d.mkv          |
        |         | c1        | nb   | lb-d  | lb-e       | lb-d.mp3          | lb-d.jpg          | lb-d.mkv          |
        
