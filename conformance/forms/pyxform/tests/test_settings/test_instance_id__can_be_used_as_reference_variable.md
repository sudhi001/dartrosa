<!-- pyxform tests/test_settings.py::TestSettings::test_instance_id__can_be_used_as_reference_variable -->
        | survey |
        | | type  | name | label         | calculation   | read_only |
        | | text  | q1   | ${instanceID} |               |           |
        | | text  | q2   | Q2            | ${instanceID} | yes       |
        
