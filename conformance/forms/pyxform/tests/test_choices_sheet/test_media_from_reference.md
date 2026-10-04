<!-- pyxform tests/test_choices_sheet.py::TestChoicesSheet::test_media_from_reference -->
        | survey |
        | | type          | name | label |
        | | select_one c1 | q1   | Q1    |

        | choices |
        | | list_name | name | audio |
        | | c1        | n1   | ${q1} |
        
