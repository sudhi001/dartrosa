// ODK Collect test forms and media (test-forms/src/main/resources),
// embedded so the tests also run on the web.

/// Forms by file name.
const forms = <String, String>{
  'one-question-editable.xml': r'''<?xml version="1.0"?>
<h:html
    xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms"
    xmlns:odk="http://www.opendatakit.org/xforms">
    <h:head>
        <h:title>One Question Editable</h:title>
        <model>
            <instance>
                <data id="one_question_editable" orx:version="1">
                    <age/>
                    <meta>
                        <instanceID/>
                    </meta>
                </data>
            </instance>
            <submission odk:client-editable="true" />
            <bind nodeset="age" type="int"/>
            <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
        </model>
    </h:head>
    <h:body>
        <input ref="/data/age">
            <label>what is your age</label>
        </input>
    </h:body>
</h:html>''',
  'selectOneExternal.xml': r'''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns:h="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <h:head>
        <h:title>selectOneExternal</h:title>
        <model odk:xforms-version="1.0.0">
            <itext>
                <translation lang="English">
                    <text id="/data/state:label">
                        <value>state</value>
                    </text>
                    <text id="/data/state/a1:label">
                        <value>Texas</value>
                    </text>
                    <text id="/data/state/a2:label">
                        <value>Washington</value>
                    </text>
                    <text id="/data/county:label">
                        <value>county</value>
                    </text>
                    <text id="/data/city:label">
                        <value>city</value>
                    </text>
                    <text id="/data/state2:label">
                        <value>state</value>
                    </text>
                    <text id="/data/state2/a1:label">
                        <value>Texas</value>
                    </text>
                    <text id="/data/state2/a2:label">
                        <value>Washington</value>
                    </text>
                    <text id="/data/county2:label">
                        <value>county</value>
                    </text>
                    <text id="/data/city2:label">
                        <value>city</value>
                    </text>
                </translation>
                <translation lang="French">
                    <text id="/data/state:label">
                        <value>Le state</value>
                    </text>
                    <text id="/data/state/a1:label">
                        <value>Le Texas</value>
                    </text>
                    <text id="/data/state/a2:label">
                        <value>La Washington</value>
                    </text>
                    <text id="/data/county:label">
                        <value>Pays</value>
                    </text>
                    <text id="/data/city:label">
                        <value>Ville</value>
                    </text>
                    <text id="/data/state2:label">
                        <value>Le state</value>
                    </text>
                    <text id="/data/state2/a1:label">
                        <value>Le Texas</value>
                    </text>
                    <text id="/data/state2/a2:label">
                        <value>La Washington</value>
                    </text>
                    <text id="/data/county2:label">
                        <value>Pays</value>
                    </text>
                    <text id="/data/city2:label">
                        <value>Ville</value>
                    </text>
                </translation>
            </itext>
            <instance>
                <data id="cascading_select_test">
                    <state />
                    <county />
                    <city />
                    <state2 />
                    <county2 />
                    <city2 />
                    <meta>
                        <instanceID />
                    </meta>
                </data>
            </instance>
            <bind nodeset="/data/state" type="string" />
            <bind nodeset="/data/county" type="string" />
            <bind nodeset="/data/city" type="string" />
            <bind nodeset="/data/state2" type="string" />
            <bind nodeset="/data/county2" type="string" />
            <bind nodeset="/data/city2" type="string" />
            <bind jr:preload="uid" nodeset="/data/meta/instanceID" readonly="true()" type="string" />
        </model>
    </h:head>
    <h:body>
        <select1 ref="/data/state">
            <label ref="jr:itext('/data/state:label')" />
            <item>
                <label ref="jr:itext('/data/state/a1:label')" />
                <value>a1</value>
            </item>
            <item>
                <label ref="jr:itext('/data/state/a2:label')" />
                <value>a2</value>
            </item>
        </select1>
        <input query="instance('counties')/root/item[state= /data/state ]" ref="/data/county">
            <label ref="jr:itext('/data/county:label')" />
        </input>
        <input query="instance('cities')/root/item[state= /data/state  and county= /data/county ]" ref="/data/city">
            <label ref="jr:itext('/data/city:label')" />
        </input>
        <select1 appearance="minimal" ref="/data/state2">
            <label ref="jr:itext('/data/state2:label')" />
            <hint>minimal</hint>
            <item>
                <label ref="jr:itext('/data/state2/a1:label')" />
                <value>a1</value>
            </item>
            <item>
                <label ref="jr:itext('/data/state2/a2:label')" />
                <value>a2</value>
            </item>
        </select1>
        <input appearance="minimal" query="instance('counties')/root/item[state= /data/state2 ]" ref="/data/county2">
            <label ref="jr:itext('/data/county2:label')" />
            <hint>minimal</hint>
        </input>
        <input appearance="minimal autocomplete" query="instance('cities')/root/item[state= /data/state2  and county= /data/county2 ]" ref="/data/city2">
            <label ref="jr:itext('/data/city2:label')" />
            <hint>minimal autocomplete</hint>
        </input>
    </h:body>
</h:html>''',
  'select_one_external.xml': r'''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns:h="http://www.w3.org/1999/xhtml" xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:jr="http://openrosa.org/javarosa" xmlns:odk="http://www.opendatakit.org/xforms" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <h:head>
    <h:title>cascading select test</h:title>
    <model odk:xforms-version="1.0.0">
      <itext>
        <translation lang="English">
          <text id="/data/state:label">
            <value>state</value>
          </text>
          <text id="/data/state/a1:label">
            <value>Texas</value>
          </text>
          <text id="/data/state/a2:label">
            <value>Washington</value>
          </text>
          <text id="/data/county:label">
            <value>county</value>
          </text>
          <text id="/data/city:label">
            <value>city</value>
          </text>
        </translation>
      </itext>
      <instance>
        <data id="cascading_select_test">
          <state />
          <county />
          <city />
          <meta>
            <instanceID />
          </meta>
        </data>
      </instance>
      <bind nodeset="/data/state" type="string" />
      <bind nodeset="/data/county" type="string" />
      <bind nodeset="/data/city" type="string" />
      <bind jr:preload="uid" nodeset="/data/meta/instanceID" readonly="true()" type="string" />
    </model>
  </h:head>
  <h:body>
    <select1 ref="/data/state">
      <label ref="jr:itext('/data/state:label')" />
      <item>
        <label ref="jr:itext('/data/state/a1:label')" />
        <value>a1</value>
      </item>
      <item>
        <label ref="jr:itext('/data/state/a2:label')" />
        <value>a2</value>
      </item>
    </select1>
    <input query="instance('counties')/root/item[state= /data/state ]" ref="/data/county">
      <label ref="jr:itext('/data/county:label')" />
    </input>
    <input query="instance('cities')/root/item[state= /data/state  and county= /data/county ]" ref="/data/city">
      <label ref="jr:itext('/data/city:label')" />
    </input>
  </h:body>
</h:html>''',
  'one-question-last-saved.xml': r'''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <h:head>
        <h:title>One Question Last Saved</h:title>
        <model>
            <instance>
                <data id="one_question_last_saved" orx:version="1">
                    <age/>
                </data>
            </instance>
            <instance id="__last-saved" src="jr://instance/last-saved" />
            <bind nodeset="age" type="int"/>
            <setvalue event="odk-instance-first-load" ref="/data/age" value=" instance('__last-saved')/data/age " />
        </model>
    </h:head>
    <h:body>
        <input ref="/data/age">
            <label>what is your age</label>
        </input>
    </h:body>
</h:html>
''',
  'one-question-last-saved-updated.xml': r'''<?xml version="1.0"?>
<h:html xmlns="http://www.w3.org/2002/xforms" xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:jr="http://openrosa.org/javarosa" xmlns:orx="http://openrosa.org/xforms" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <h:head>
        <h:title>One Question Last Saved</h:title>
        <model>
            <instance>
                <data id="one_question_last_saved" orx:version="2">
                    <age/>
                </data>
            </instance>
            <instance id="__last-saved" src="jr://instance/last-saved" />
            <bind nodeset="age" type="int"/>
            <setvalue event="odk-instance-first-load" ref="/data/age" value=" instance('__last-saved')/data/age " />
        </model>
    </h:head>
    <h:body>
        <input ref="/data/age">
            <label>what is your age?</label>
        </input>
    </h:body>
</h:html>
''',
};

/// Media files by path.
const media = <String, String>{
  'selectOneExternal-media/itemsets.csv':
      r'''"list_name","name","label::English","state","county","label::French"
"states","a1","Texas","","","Le Texas"
"states","a2","Washington","","","La Washington"
"counties","b1","King","a2","","Le King"
"counties","b2","Pierce","a2","","La Pierce"
"counties","b3","King","a1","","Le King"
"counties","b4","Cameron","a1","","La Cameron"
"cities","dumont","Dumont","a1","b3","Le Dumont"
"cities","finney","Finney","a1","b3","La Finney"
"cities","brownsville","brownsville","a1","b4","Le brownsville"
"cities","harlingen","harlingen","a1","b4","La harlingen"
"cities","seattle","Seattle","a2","b3","Le Seattle"
"cities","redmond","Redmond","a2","b3","La Redmond"
"cities","tacoma","Tacoma","a2","b2","Le Tacoma"
"cities","puyallup","Puyallup","a2","b2","La Puyallup"
''',
};
