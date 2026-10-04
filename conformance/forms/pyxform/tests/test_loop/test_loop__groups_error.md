<!-- pyxform tests/test_loop.py::TestLoopOutput::test_loop__groups_error -->
        | survey |
        |        | type               | name | label             |
        |        | begin_loop over c1 | l1   |                   |
        |        | begin_group        | g1   |                   |
        |        | integer            | q1   | Age               |
        |        | select_one c2      | q2   | Size of %(label)s |
        |        | end_group          |      |                   |
        |        | end_loop           |      |                   |

        | choices |
        |         | list_name | name   | label   |
        |         | c1        | thing1 | Thing 1 |
        |         | c1        | thing2 | Thing 2 |
        |         | c2        | type1  | Big     |
        |         | c2        | type2  | Small   |
        
