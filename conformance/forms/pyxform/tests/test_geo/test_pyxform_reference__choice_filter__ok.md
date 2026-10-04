<!-- pyxform tests/test_geo.py::TestParameterReferenceGeometryOutput::test_pyxform_reference__choice_filter__ok -->
        | survey |
        | | type         | name     | label | parameters                     | choice_filter |
        | | begin_repeat | _c1A   | R1    |                                |               |
        | | geopoint     | geometry | Q1    |                                |               |
        | | text         | q2       | Q2    |                                |               |
        | | end_repeat   | _c1A   |       |                                |               |
        | | geotrace       | q3       | Q3    | reference-geometry=${_c1A} | ${q2} = 1   |
        
