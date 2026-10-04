<!-- pyxform tests/test_range.py::TestRangeParsing::test_tick_labelset_choice_not_aligned_with_tick_interval__both__ok -->
        | survey |
        | | type  | name | label | parameters                                             |
        | | range | q1   | Q1    | start=1 end=12 step=2 tick_interval=4 tick_labelset=c1 |

        | choices |
        | | list_name | name    | label |
        | | c1        | 1       | N1    |
        | | c1        | 5       | N2    |
        | | c1        | 9       | N3    |
        
