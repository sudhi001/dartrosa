<!-- pyxform tests/test_sms.py::SMSTest::test_sms_info -->
        | settings |
        | | form_title | form_id  | sms_keyword | sms_separator | sms_allow_media | sms_date_format | sms_datetime_format |
        | | SMS        | sms_info | inf         | +             | 1               | %Y-%m-%d        | %Y-%m-%d-%H:%M      |

        | survey |
        | | type                     | name         | sms_field | label                         |
        | | begin_group              | section1     | a         |                               |
        | | integer                  | age          | q1        | How old are you?              |
        | | select_one yes_no        | has_children | q2        | Do you have any children?     |
        | | end_group                |              |           |                               |
        | | begin_group              | medias       | c         |                               |
        | | image                    | picture      |           | May I take your picture?      |
        | | geopoint                 | gps          |           | Record your GPS coordinates.  |
        | | end_group                |              |           |                               |
        | | begin_group              | browsers     | b         |                               |
        | | select_multiple browsers | web_browsers | q5        | What web browsers do you use? |
        | | end_group                |              |           |                               |

        | choices |
        | | list_name | name    | sms_option | label             |
        | | yes_no    | n       | n          | no                |
        | | yes_no    | y       | y          | yes               |
        | | browsers  | firefox | ff         | Mozilla Firefox   |
        | | browsers  | chrome  | gc         | Google Chrome     |
        
