// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Forms and media from ODK Collect's test-forms module
// (test-forms/src/main/resources), embedded so the tests run on the web.

/// Collect test forms by file name.
const forms = {
  'pull_data.xml': r'''<?xml version="1.0"?>
<h:html xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms"
    xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns="http://www.w3.org/2002/xforms">
    <h:head>
        <h:title>pull_data</h:title>
        <model odk:xforms-version="1.0.0">
            <instance>
                <data id="pull_data">
                    <fruit />
                    <note_country />
                    <meta>
                        <instanceID />
                    </meta>
                </data>
            </instance>
            <instance id="fruits" src="jr://file-csv/fruits.csv" />
            <bind calculate="pulldata('fruits', 'name', 'name_key', 'mango')" nodeset="/data/fruit"
                type="string" />
            <bind nodeset="/data/note_country" readonly="true()" type="string" />
            <bind nodeset="/data/meta/instanceID" readonly="true()" type="string"
                jr:preload="uid" />
        </model>
    </h:head>
    <h:body>
        <input ref="/data/note_country">
            <label>The fruit <output value=" /data/fruit " /> is pulled csv data.
            </label>
        </input>
    </h:body>
</h:html>
''',
  'external-csv-search.xml': r'''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <h:head>
    <h:title>external-csv-search</h:title>
    <model>
      <instance>
        <external-csv-search id="external-csv-search">
          <multi_produce/>
          <produce_search/>
          <produce/>
          <meta>
            <instanceID/>
          </meta>
        </external-csv-search>
      </instance>
      <bind nodeset="/external-csv-search/multi_produce" type="select"/>
      <bind nodeset="/external-csv-search/produce_search" type="string"/>
      <bind nodeset="/external-csv-search/produce" type="select1"/>
      <bind calculate="concat('uuid:', uuid())" nodeset="/external-csv-search/meta/instanceID" readonly="true()" type="string"/>
    </model>
  </h:head>
  <h:body>
    <select appearance="search('external-csv-search-produce')" ref="/external-csv-search/multi_produce">
      <label>Multiple produce</label>
      <item>
        <label>label</label>
        <value>name</value>
      </item>
    </select>
    <input ref="/external-csv-search/produce_search">
      <label>Produce search</label>
    </input>
    <select1 appearance="search('external-csv-search-produce', 'contains', 'name',  /external-csv-search/produce_search )" ref="/external-csv-search/produce">
      <label>Produce</label>
      <item>
        <label>label</label>
        <value>name</value>
      </item>
    </select1>
  </h:body>
</h:html>
''',
  'external-csv-search-broken.xml': r'''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <h:head>
    <h:title>external-csv-search</h:title>
    <model>
      <instance>
        <external-csv-search id="external-csv-search">
          <produce_search/>
          <produce/>
          <meta>
            <instanceID/>
          </meta>
        </external-csv-search>
      </instance>
      <bind nodeset="/external-csv-search/produce_search" type="string"/>
      <bind nodeset="/external-csv-search/produce" type="select1"/>
      <bind calculate="concat('uuid:', uuid())" nodeset="/external-csv-search/meta/instanceID" readonly="true()" type="string"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/external-csv-search/produce_search">
      <label>Produce search</label>
    </input>
    <select1 appearance="search('external-csv-search-produce', 'contains', 'wat',  /external-csv-search/produce_search )" ref="/external-csv-search/produce">
      <label>Produce</label>
      <item>
        <label>label</label>
        <value>name</value>
      </item>
    </select1>
  </h:body>
</h:html>
''',
  'dynamic_and_static_choices.xml': r'''<?xml version="1.0"?>
<h:html
    xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms"
    xmlns:odk="http://www.opendatakit.org/xforms">
    <h:head>
        <h:title>dynamic_and_static_choices</h:title>
        <model odk:xforms-version="1.0.0">
            <instance>
                <data id="dynamic_and_static_choices">
                    <fruits/>
                    <numbers/>
                    <meta>
                        <instanceID/>
                    </meta>
                </data>
            </instance>
            <bind nodeset="/data/fruits" type="string"/>
            <bind nodeset="/data/numbers" type="string"/>
            <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
        </model>
    </h:head>
    <h:body>
        <select1 ref="/data/fruits" appearance="search('fruits')">
            <label>Choose a fruit</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
            <item>
                <label>None of the above</label>
                <value>0</value>
            </item>
        </select1>
        <select1 ref="/data/numbers" appearance="search('numbers')">
            <label>Choose a number</label>
            <item>
                <label>0</label>
                <value>0</value>
            </item>
            <item>
                <label>1</label>
                <value>1</value>
            </item>
        </select1>
    </h:body>
</h:html>''',
  'simple-search-external-csv.xml': r'''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns:h="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <h:head>
        <h:title>simple-search-external-csv</h:title>
        <model>
            <instance>
                <simple-search-external-csv id="simple-search-external-csv">
                    <fruit1 />
                    <note_fruit />
                </simple-search-external-csv>
            </instance>
            <bind nodeset="/simple-search-external-csv/fruit1" type="select1" />
            <bind nodeset="/simple-search-external-csv/note_fruit" readonly="true()" type="string" />
        </model>
    </h:head>
    <h:body>
        <select1 appearance="search('simple-search-external-csv-fruits')" ref="/simple-search-external-csv/fruit1">
            <label>Select from a CSV using search() appearance/function</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select1>
        <input ref="/simple-search-external-csv/note_fruit">
            <label>
                The fruit <output value=" /simple-search-external-csv/fruit1 " /> pulled from csv
            </label>
        </input>
    </h:body>
</h:html>''',
  'different-search-appearances.xml': r'''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns:h="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <h:head>
        <h:title>different-search-appearances</h:title>
        <model>
            <instance>
                <different-search-appearances id="different-search-appearances">
                    <fruit1 />
                    <note_fruit />
                    <animal1 />
                    <animal2 />
                    <animal3 />
                    <fruit2 />
                    <fruit3 />
                    <fruit4 />
                    <animal4 />
                    <animal5 />
                    <animal6 />
                    <fruit5 />
                    <fruit6 />
                    <meta>
                        <instanceID />
                    </meta>
                </different-search-appearances>
            </instance>
            <bind nodeset="/different-search-appearances/fruit1" type="select1" />
            <bind nodeset="/different-search-appearances/note_fruit" readonly="true()" type="string" />
            <bind nodeset="/different-search-appearances/animal1" type="select1" />
            <bind nodeset="/different-search-appearances/animal2" type="select1" />
            <bind nodeset="/different-search-appearances/animal3" type="select1" />
            <bind nodeset="/different-search-appearances/fruit2" type="select1" />
            <bind nodeset="/different-search-appearances/fruit3" type="select1" />
            <bind nodeset="/different-search-appearances/fruit4" type="select" />
            <bind nodeset="/different-search-appearances/animal4" type="select" />
            <bind nodeset="/different-search-appearances/animal5" type="select" />
            <bind nodeset="/different-search-appearances/animal6" type="select" />
            <bind nodeset="/different-search-appearances/fruit5" type="select" />
            <bind nodeset="/different-search-appearances/fruit6" type="select" />
            <bind calculate="concat('uuid:', uuid())" nodeset="/different-search-appearances/meta/instanceID" readonly="true()" type="string" />
        </model>
    </h:head>
    <h:body>
        <select1 appearance="search('fruits')" ref="/different-search-appearances/fruit1">
            <label>Select one from a CSV using search() appearance/function</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select1>
        <input ref="/different-search-appearances/note_fruit">
            <label>
                The fruit <output value=" /different-search-appearances/fruit1 " /> pulled from csv
            </label>
        </input>
        <select1 ref="/different-search-appearances/animal1">
            <label>Static select one with no appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select1>
        <select1 appearance="search" ref="/different-search-appearances/animal2">
            <label>Static select one with search appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select1>
        <select1 appearance="autocomplete" ref="/different-search-appearances/animal3">
            <label>Static select one with autocomplete appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select1>
        <select1 appearance="search search('fruits')" ref="/different-search-appearances/fruit2">
            <label>Select one from a CSV using search() appearance/function and search appearance</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select1>
        <select1 appearance="autocomplete search('fruits')" ref="/different-search-appearances/fruit3">
            <label>Select one from a CSV using search() appearance/function and autocomplete appearance</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select1>
        <select appearance="search('fruits')" ref="/different-search-appearances/fruit4">
            <label>Select multiple from a CSV using search() appearance/function</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select>
        <select ref="/different-search-appearances/animal4">
            <label>Static select multiple with no appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select>
        <select appearance="search" ref="/different-search-appearances/animal5">
            <label>Static select multiple with search appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select>
        <select appearance="autocomplete" ref="/different-search-appearances/animal6">
            <label>Static select multiple with autocomplete appearance</label>
            <item>
                <label>Wolf</label>
                <value>wolf</value>
            </item>
            <item>
                <label>Warthog</label>
                <value>warthog</value>
            </item>
            <item>
                <label>Raccoon</label>
                <value>raccoon</value>
            </item>
            <item>
                <label>Rabbit</label>
                <value>rabbit</value>
            </item>
        </select>
        <select appearance="search search('fruits')" ref="/different-search-appearances/fruit5">
            <label>Select multiple from a CSV using search() appearance/function and search appearance</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select>
        <select appearance="autocomplete search('fruits')" ref="/different-search-appearances/fruit6">
            <label>Select multiple from a CSV using search() appearance/function and autocomplete appearance</label>
            <item>
                <label>name</label>
                <value>name_key</value>
            </item>
        </select>
    </h:body>
</h:html>''',
  'search-with-last-saved.xml': r'''<?xml version="1.0"?>
<h:html
    xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms"
    xmlns:odk="http://www.opendatakit.org/xforms">
    <h:head>
        <h:title>Search with last-saved</h:title>
        <model odk:xforms-version="1.0.0">
            <instance>
                <data id="search-with-last-saved">
                    <group>
                        <fruit/>
                        <number/>
                    </group>
                    <meta>
                        <instanceID/>
                    </meta>
                </data>
            </instance>
            <instance id="__last-saved" src="jr://instance/last-saved"/>
            <bind nodeset="/data/group/fruit" type="string"/>
            <setvalue ref="/data/group/fruit" value=" instance('__last-saved')/data/group/fruit " event="odk-instance-first-load"/>
            <bind nodeset="/data/group/number" type="string"/>
            <setvalue ref="/data/group/number" value=" instance('__last-saved')/data/group/number " event="odk-instance-first-load"/>
            <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
        </model>
    </h:head>
    <h:body>
        <group appearance="field-list" ref="/data/group">
            <select1 ref="/data/group/fruit" appearance="search('fruits')">
                <label>Select fruit</label>
                <item>
                    <label>name</label>
                    <value>name_key</value>
                </item>
            </select1>
            <select ref="/data/group/number" appearance="search('external_data')">
                <label>Select numbers</label>
                <item>
                    <label>label</label>
                    <value>name</value>
                </item>
            </select>
        </group>
    </h:body>
</h:html>
''',
};

/// Collect test media by file name.
const media = {
  'fruits.csv': r'''name_key,name
mango,Mango
oranges,Oranges
strawberries,Strawberries''',
  'external-csv-search-produce.csv': r'''name,label
artichoke,Artichoke
apple,Apple
banana,Banana
blueberry,Blueberry
cherimoya,Cherimoya
carrot,Carrot''',
  'simple-search-external-csv-fruits.csv': r'''name_key,name
mango,Mango
oranges,Oranges
strawberries,Strawberries''',
  'external_data.csv': r'''name,label
one,One
two,Two
three,Three
''',
};
