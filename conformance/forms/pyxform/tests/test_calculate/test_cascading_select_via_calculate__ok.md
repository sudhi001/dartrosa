<!-- pyxform tests/test_calculate.py::TypedCalculatesTest::test_cascading_select_via_calculate__ok -->
        | survey |
        | | type          | name | label | relevant   |  calculation          |
        | | select_one c1 | q1   | Q1    |            |                       |
        | | select_one c2 | q2   | Q2    | ${q1}='n1' |                       |
        | | select_one c3 | q3   | Q3    | ${q1}='n2' |                       |
        | | calculate     | q4   | Q4    |            | if(${q1}='n1', ${q2}, if(${q1}='n2', ${q3}, 'Error')) |
        | | select_one c4 | q5   | Q5    | ${q4}='n3' |                       |
        | | select_one c5 | q6   | Q6    | ${q4}='n4' |                       |
        | | select_one c6 | q7   | Q7    | ${q4}='n5' |                       |
        | | select_one c7 | q8   | Q8    | ${q4}='n6' |                       |
        | | calculate     | q9   | Q9    |            | if(${q4}='n3', ${q5}, if(${q4}='n4', ${q6}, if(${q4}='n5', ${q7}, if(${q4}='n6', ${q8}, 'Error')))) |

        | choices |
        | | list_name | name | label |
        | | c1        | n1   | N1    |
        | | c1        | n2   | N2    |
        | | c2        | n3   | N3    |
        | | c2        | n4   | N4    |
        | | c3        | n5   | N5    |
        | | c3        | n6   | N6    |
        | | c4        | n7   | N7    |
        | | c4        | n8   | N8    |
        | | c5        | n9   | N9    |
        | | c5        | n10  | N10   |
        | | c6        | n11  | N11   |
        | | c6        | n12  | N12   |
        | | c7        | n13  | N13   |
        | | c7        | n14  | N14   |
        
