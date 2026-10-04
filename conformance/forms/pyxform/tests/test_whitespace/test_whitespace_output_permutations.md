<!-- pyxform tests/test_whitespace.py::WhitespaceTest::test_whitespace_output_permutations -->
        | survey |              |      |
        |        | type         | name | label                |
        |        | text         | A    | None                 |
        |        | text         | B1   | Before ${B1}           |
        |        | text         | C1   | ${B1} After            |
        |        | text         | D1   | Before x2 ${B1} ${B1}    |
        |        | text         | E1   | ${B1} ${B1} After x2     |
        |        | text         | F1   | ${B1} Between ${B1}      |
        |        | text         | G1   | Wrap ${B1} in text     |
        |        | text         | H1   | Wrap ${B1} in ${B1} text |
        |        | text         | I1   | Wrap ${B1} in ${B1}      |
        |        | text         | J1   | Encode ${B1} < ${B1}     |
        
