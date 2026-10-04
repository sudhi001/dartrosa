<!-- pyxform tests/test_repeat.py::TestRepeatOutput::test_repeat_relative_reference -->
                | survey |              |          |            |                      |
                |        | type         | name     | relevant   | label                |
                |        | text         | Z        |            | Fruit                |
                |        | begin repeat | section  |            | Section              |
                |        | text         | AA       |            | Anything really      |
                |        | text         | A        |            | A oat                |
                |        | text         | B        | ${A}='oat' | B w ${A}             |
                |        | note         | note1    |            | Noted ${AA} w ${A}   |
                |        | end repeat   |          |            |                      |
                |        |              |          |            |                      |
                |        | begin repeat | section2 |            | Section 2            |
                |        | text         | C        |            | C                    |
                |        | begin group  | sectiona |            | Section A            |
                |        | text         | D        |            | D oat                |
                |        | text         | E        | ${D}='oat' | E w ${Z}             |
                |        | note         | note2    |            | Noted ${C} w ${E}    |
                |        | end group    |          |            |                      |
                |        | note         | note3    |            | Noted ${C} w ${E}    |
                |        | end repeat   |          |            |                      |
                |        |              |          |            |                      |
                |        | begin repeat | section3 |            | Section 3            |
                |        | text         | FF       |            | F any text           |
                |        | text         | F        |            | F oat                |
                |        | begin group  | sectionb |            | Section B            |
                |        | text         | G        |            | G oat                |
                |        | text         | H        | ${G}='oat' | H w ${Z}             |
                |        | note         | note4    |            | Noted ${H} w ${Z}    |
                |        | end group    |          |            |                      |
                |        | begin repeat | sectionc |            | Section B            |
                |        | text         | I        |            | I                    |
                |        | text         | J        | ${I}='oat' | J w ${Z}             |
                |        | text         | K        | ${F}='oat' | K w ${Z}             |
                |        | text         | L        | ${G}='oat' | K w ${Z}             |
                |        | note         | note5    |            | Noted ${FF} w ${H}   |
                |        | note         | note6    |            | JKL #${J}#${K}#${L}  |
                |        | end repeat   |          |            |                      |
                |        | note         | note7    |            | Noted ${FF} w ${H}   |
                |        | begin group  | sectiond |            | Section D            |
                |        | text         | M        |            | M oat                |
                |        | text         | N        | ${G}='oat' | N w ${Z}             |
                |        | text         | O        | ${M}='oat' | O w ${Z}             |
                |        | note         | note8    |            | NO #${N} #${O}       |
                |        | end group    |          |            |                      |
                |        | note         | note9    |            | ${FF} ${H} ${N} ${N} |
                |        | end repeat   |          |            |                      |
                |        |              |          |            |                      |
                
