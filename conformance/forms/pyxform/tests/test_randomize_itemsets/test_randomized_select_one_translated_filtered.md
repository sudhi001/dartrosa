<!-- pyxform tests/test_randomize_itemsets.py::RandomizeItemsetsTest::test_randomized_select_one_translated_filtered -->
        | survey  |
        |         | type          | name | label::English (en) | parameters     | choice_filter |
        |         | text          | q0   | Question 0          |                |               |
        |         | select_one c1 | q1   | Question 1          | randomize=True | ${q0} = cf    |
        | choices |           |      |       |
        |         | list_name | name | label::English (en) | cf |
        |         | c1        | a    | A                   | 1  |
        |         | c1        | b    | B                   | 2  |
        
