<!-- pyxform tests/test_settings.py::TestSettings::test_clean_text_values__no -->
        | survey  |                    |      |       |             |
        |         | type               | name | label | calculation |
        |         | integer            | q1   | Q1    | string-length('abc  def') |
        |         | select_one c1      | q2   | Q2    |             |
        |         | select_multiple c2 | q3   | Q3    |             |
        | choices  |
        |          | list_name | name | label |
        |          | c1        | a  b | c  1  |
        |          | c2        | b    | c  2  |
        | settings |                   |
        |          | clean_text_values |
        |          | no                |
        
