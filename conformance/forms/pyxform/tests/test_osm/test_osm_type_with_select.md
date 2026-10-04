<!-- pyxform tests/test_osm.py::OSMWidgetsTest::test_osm_type_with_select -->
        | survey  |
        |         | type              | name      | label    |
        |         | osm               | osm_road  | Road     |
        |         | osm building_tags | osm_build | Building |
        |         | select_one c1     | q1        | Q1       |
        | osm     |
        |         | list_name     | name      | label |
        |         | building_tags | name      | Name  |
        |         | building_tags | addr:city | City  |
        | choices |
        |         | list_name | name | label |
        |         | c1        | n1   | l1    |
        |         | c1        | n2   | l2    |
        
