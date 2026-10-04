<!-- pyxform tests/entities/test_entities.py::TestEntitiesOutput::test_save_to__multiple_entities__repeat_group -->
        | survey |
        | | type         | name | label | save_to |
        | | begin_repeat | r1   | R1    |         |
        | | begin_group  | g1   | G1    |         |
        | | text         | q1   | Q1    | e1#e1p1 |
        | | begin_group  | g2   | G1    |         |
        | | text         | q2   | Q2    | e2#e2p1 |
        | | end_group    | g2   |       |         |
        | | end_group    | g1   |       |         |
        | | end_repeat   | r1   |       |         |

        | entities |
        | | list_name | label |
        | | e1        | E1    |
        | | e2        | E2    |
        
