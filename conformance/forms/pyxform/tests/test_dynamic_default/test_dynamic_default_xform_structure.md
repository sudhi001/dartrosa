<!-- pyxform tests/test_dynamic_default.py::TestDynamicDefaultSimpleInput::test_dynamic_default_xform_structure -->
        | survey |            |          |          |               |                    |
        |        | type       | name     | label    | default       | label::French (fr) |
        |        | text       | ref_text | RefText  |               | Oui                |
        |        | integer    | ref_int  | RefInt   |               |                    |
                |        | integer | q0 | Q0 | foo |      |
                |        | integer | q1 | Q1 | 123 |      |
                |        | text | q2 | Q2 | bar123 |      |
                |        | text | q3 | Q3 | https://my-site.com |      |
                |        | text | q4 | Q4 | (https://mysite.com) |      |
                |        | text | q5 | Q5 | go to https://mysite.com |      |
                |        | text | q6 | Q6 | Repeat after me: '~!@#$%^&()_ |      |
                |        | text | q7 | Q7 | not_func$ |      |
                |        | text | q8 | Q8 | f-g |      |
                |        | text | q9 | Q9 | f-4 |      |
                |        | text | q10 | Q10 | ./f-4 |      |
                |        | integer | q11 | Q11 | f-g |      |
                |        | integer | q12 | Q12 | f-4 |      |
                |        | date | q13 | Q13 | 2022-03-14 |      |
                |        | date | q14 | Q14 | -2022-03-14 |      |
                |        | time | q15 | Q15 | 01:02:55 |      |
                |        | time | q16 | Q16 | 01:02:55Z |      |
                |        | time | q17 | Q17 | 01:02:55+00:00 |      |
                |        | time | q18 | Q18 | 01:02:55+10:00 |      |
                |        | time | q19 | Q19 | 01:02:55-07:00 |      |
                |        | date | q20 | Q20 | 2022-03-14T01:02:55 |      |
                |        | dateTime | q21 | Q21 | 2022-03-14T01:02:55Z |      |
                |        | dateTime | q22 | Q22 | 2022-03-14T01:02:55+00:00 |      |
                |        | dateTime | q23 | Q23 | 2022-03-14T01:02:55+10:00 |      |
                |        | dateTime | q24 | Q24 | 2022-03-14T01:02:55-07:00 |      |
                |        | geopoint | q25 | Q25 | 32.7377112 -117.1288399 14 5.01 |      |
                |        | geotrace | q26 | Q26 | 32.7377112 -117.1288399 14 5.01;32.7897897 -117.9876543 14 5.01 |      |
                |        | geoshape | q27 | Q27 | 32.7377112 -117.1288399 14 5.01;32.7897897 -117.9876543 14 5.01;32.1231231 -117.1145877 14 5.01 |      |
                |        | integer | q28 | Q28 | random() |      |
                |        | text | q29 | Q29 | ends-with('mystr', "str") |      |
                |        | text | q30 | Q30 | ends-with(../t2, ./t4) |      |
                |        | text | q31 | Q31 | jr:itext('/test/ref_text:label') |      |
                |        | text | q32 | Q32 | if(../t2 = 'test', 1, 2) + 15 - int(1.2) |      |
                |        | text | q33 | Q33 | 1 + decimal-date-time(now()) |      |
                |        | text | q34 | Q34 | concat(if(../t1 = "this", 'go', "to"), "https://mysite.com") |      |
                |        | integer | q35 | Q35 | 7 - 4 |      |
                |        | text | q36 | Q36 | 3 mod 3 |      |
                |        | text | q37 | Q37 | 5 div 5 |      |
                |        | text | q38 | Q38 | 2 + 3 * 4 |      |
                |        | text | q39 | Q39 | 5 div 5 - 5 |      |
                |        | integer | q40 | Q40 | random() + 2 * 5 |      |
                |        | text | q41 | Q41 | ./f - 4 |      |
                |        | text | q42 | Q42 | ../t2 - ./t4 |      |
                |        | text | q43 | Q43 | 1 + 2 - 3 * 4 div 5 mod 6 |      |
                |        | date | q44 | Q44 | concat('2022-03', '-14') |      |
                |        | text | q45 | Q45 | ${ref_text} |      |
                |        | integer | q46 | Q46 | ${ref_int} |      |
                |        | text | q47 | Q47 | ${last-saved#ref_text} |      |
                |        | integer | q48 | Q48 | if(${last-saved#ref_int} = '', 0, ${last-saved#ref_int} + 1) |      |
        
