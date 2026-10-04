<!-- pyxform tests/entities/test_create_repeat.py::TestEntitiesCreateRepeat::test_somewhat_ambiguous_repeat_nesting_references_with_saveto_and_competing_lists -->
        | survey |
        | | type         | name  | label | save_to |
        | | begin_repeat | r1    | R1    |         |
        | | begin_group  | g1    | G1    |         |
        | | text         | q1    | Q1    |         |
        | | begin_repeat | r2    | R2    |         |
        | | begin_group  | g2    | G2    |         |
        | | text         | q2    | Q2    | e1#e1p1 |
        | | begin_group  | g3    | G3    |         |
        | | text         | q3    | Q3    |         |
        | | text         | q4    | Q4    | e2#e2p1 |
        | | end_group    |       |       |         |
        | | end_group    |       |       |         |
        | | end_repeat   |       |       |         |
        | | end_group    |       |       |         |
        | | end_repeat   |       |       |         |

        | entities |
        | | list_name | label                                 |
        | | e1        | concat(${q1}, " ", ${q2}, " ", ${q3}) |
        | | e2        | concat(${q1}, " ", ${q2}, " ", ${q3}) |
        
