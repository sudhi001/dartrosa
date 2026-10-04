<!-- pyxform tests/test_range.py::TestRangeParsing::test_tick_labelset_no_ticks_too_many_choices__allow_duplicates__ok -->
        | settings |
        | | allow_choice_duplicates |
        | | yes                     |

        | survey |
        | | type  | name | label | parameters              | appearance |
        | | range | q1   | Q1    | step=1 tick_labelset=c1 | no-ticks   |

        | choices |
        | | list_name | name | label |
        | | c1        | 1    | N1    |
        | | c1        | 1    | N2    |
        | | c1        | 10   | N3    |
        
