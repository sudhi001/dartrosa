<!-- pyxform tests/entities/test_entities.py::TestEntitiesParsing::test_unsolvable_meta_topology__depth_1_repeat__conflict_2_group__repeat__saveto_only__ok -->
        | survey |
        | | type              | name | label | save_to |
        | | begin_repeat      | r1   | R1    |         | e1 - q1, q2
        | |   text            | q1   | Q1    | e1#e1p1 |
        | |   begin_group     | g1   | G1    |         |
        | |     text          | q2   | Q2    | e1#e1p2 |
        | |     begin_repeat  | r2   | R2    |         | e2 - q3, q4
        | |       begin_group | g2   | G2    |         |
        | |         text      | q3   | Q3    | e2#e2p1 |
        | |       end_group   | g2   |       |         |
        | |       begin_group | g3   | G3    |         |
        | |         text      | q4   | Q4    | e2#e2p2 |
        | |       end_group   | g3   |       |         |
        | |     end_repeat    | r2   |       |         |
        | |   end_group       | g1   |       |         |
        | | end_repeat        |      |       |         |

        | entities |
        | | list_name | label |
        | | e1        | E1    |
        | | e2        | E2    |
        
