<!-- pyxform tests/test_sheet_columns.py::TestHeaderProcessing::test_choice_filter_columns_not_normalised -->
        | survey  |
        |         | type          | name | label | choice_filter |
        |         | text          | q0   | Q0    |               |
        |         | select_one c1 | q1   | Q1    | ${q0} = CF or ${q0} = A_B or ${q0} = Cd or ${q0} = h-I or ${q0} = J.k |
        | choices |
        |         | list name | name | label | CF | A_B | Cd | e f | h-I | J.k |
        |         | c1        | na   | la    | a1 | a2  | a3 | a4  | a5  | a6  |
        |         | c1        | nb   | lb    | b1 | b2  | b3 | b4  | b5  | b6  |
        
