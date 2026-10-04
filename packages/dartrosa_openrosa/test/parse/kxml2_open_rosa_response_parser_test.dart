// Port of Collect's Kxml2OpenRosaResponseParserTest, plus form list cases.
import 'package:dartrosa/javarosa.dart' show getXmlDocument;
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

const parser = Kxml2OpenRosaResponseParser();

String manifest(String mediaFile) =>
    '''
<?xml version='1.0' encoding='UTF-8' ?>
<manifest xmlns="http://openrosa.org/xforms/xformsManifest">
$mediaFile
</manifest>''';

void main() {
  test('#parseFormList when document is empty, returns null', () {
    expect(parser.parseFormList(null), isNull);
  });

  test(
    '#parseFormList when xform hash is missing prefix, returns null hash for item',
    () {
      const response = '''
<?xml version='1.0' encoding='UTF-8' ?>
<xforms xmlns="http://openrosa.org/xforms/xformsList">
    <xform>
        <formID>id</formID>
        <name>form name</name>
        <version>1</version>
        <hash>blahblah</hash>
        <downloadUrl>http://example.com</downloadUrl>
    </xform>
</xforms>''';
      final formList = parser.parseFormList(getXmlDocument(response))!;
      expect(formList[0].hash, isNull);
    },
  );

  test('#parseManifest when media file hash is empty, returns null', () {
    final doc = getXmlDocument(
      manifest('''
    <mediaFile>
        <filename>badger.png</filename>
        <hash></hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
    </mediaFile>'''),
    );
    expect(parser.parseManifest(doc), isNull);
  });

  test('#parseManifest when document is empty, returns null', () {
    expect(parser.parseManifest(null), isNull);
  });

  test('#parseManifest sanitizes media file names', () {
    final doc = getXmlDocument(
      manifest('''
    <mediaFile>
        <filename>/../badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
    </mediaFile>'''),
    );
    final mediaFiles = parser.parseManifest(doc)!;
    expect(mediaFiles.length, 1);
    expect(mediaFiles[0].filename, 'badgers.csv');
  });

  test(
    '#parseManifest when media file has type entityList returns it with entity list type',
    () {
      final doc = getXmlDocument(
        manifest('''
    <mediaFile type="entityList">
        <filename>badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
        <integrityUrl>https://some.server/forms/12/integrity</integrityUrl>
    </mediaFile>'''),
      );
      final mediaFiles = parser.parseManifest(doc)!;
      expect(mediaFiles.length, 1);
      expect(mediaFiles[0].type, MediaFileType.entityList);
    },
  );

  test('#parseManifest reads approvalEntityList type', () {
    final doc = getXmlDocument(
      manifest('''
    <mediaFile type="approvalEntityList">
        <filename>badgers.csv</filename>
        <hash>md5:blah</hash>
        <downloadUrl>http://x</downloadUrl>
    </mediaFile>'''),
    );
    final mediaFiles = parser.parseManifest(doc)!;
    expect(mediaFiles[0].type, MediaFileType.approvalEntityList);
    expect(mediaFiles[0].hash, 'blah');
  });

  test(
    '#parseManifest when media file does not have type returns it with null type',
    () {
      final doc = getXmlDocument(
        manifest('''
    <mediaFile type="blah">
        <filename>badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
    </mediaFile>'''),
      );
      final mediaFiles = parser.parseManifest(doc)!;
      expect(mediaFiles.length, 1);
      expect(mediaFiles[0].type, isNull);
    },
  );

  test(
    '#parseManifest when media file has an unrecognized type returns it with null type',
    () {
      final doc = getXmlDocument(
        manifest('''
    <mediaFile>
        <filename>badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
    </mediaFile>'''),
      );
      final mediaFiles = parser.parseManifest(doc)!;
      expect(mediaFiles.length, 1);
      expect(mediaFiles[0].type, isNull);
    },
  );

  test('#parseManifest includes integrityUrl when there is one', () {
    final doc = getXmlDocument(
      manifest('''
    <mediaFile type="entityList">
        <filename>badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
        <integrityUrl>https://some.server/forms/12/integrity</integrityUrl>
    </mediaFile>'''),
    );
    final mediaFiles = parser.parseManifest(doc)!;
    expect(mediaFiles.length, 1);
    expect(
      mediaFiles[0].integrityUrl,
      'https://some.server/forms/12/integrity',
    );
  });

  test("#parseManifest does not include integrityUrl when there isn't one", () {
    final doc = getXmlDocument(
      manifest('''
    <mediaFile>
        <filename>badgers.csv</filename>
        <hash>blah</hash>
        <downloadUrl>http://funk.appspot.com/binaryData?blobKey=%3A477e3</downloadUrl>
    </mediaFile>'''),
    );
    final mediaFiles = parser.parseManifest(doc)!;
    expect(mediaFiles.length, 1);
    expect(mediaFiles[0].integrityUrl, isNull);
  });

  test(
    '#parseManifest returns null if a media file with type entityList is missing integrityUrl',
    () {},
    skip:
        'Ignored in Collect: this would break servers that had implemented '
        'type before integrityUrl was added to the spec.',
  );

  test(
    '#parseIntegrityResponse returns null when the response structure is incorrect',
    () {
      const noData = '''
<?xml version="1.0" encoding="UTF-8"?>
<blah>
    <entities>
        <entity id="958e00b2-43f5-4d21-8adb-3d27aaa045f5">
            <deleted>true</deleted>
        </entity>
    </entities>
</blah>''';
      const noEntities = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <stuff>
        <entity id="958e00b2-43f5-4d21-8adb-3d27aaa045f5">
            <deleted>true</deleted>
        </entity>
    </stuff>
</data>''';
      const noDeleted = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <entities>
        <entity id="958e00b2-43f5-4d21-8adb-3d27aaa045f5">
            <blah>true</blah>
        </entity>
    </entities>
</data>''';
      const emptyDeleted = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <entities>
        <entity id="958e00b2-43f5-4d21-8adb-3d27aaa045f5">
            <deleted></deleted>
        </entity>
    </entities>
</data>''';
      const invalidDeleted = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <entities>
        <entity id="958e00b2-43f5-4d21-8adb-3d27aaa045f5">
            <deleted>yes</deleted>
        </entity>
    </entities>
</data>''';
      for (final doc in [
        noData,
        noEntities,
        noDeleted,
        emptyDeleted,
        invalidDeleted,
      ]) {
        expect(
          parser.parseIntegrityResponse(getXmlDocument(doc)),
          isNull,
          reason: 'The following should not be parsed:\n$doc\n\n',
        );
      }
    },
  );

  test(
    '#parseIntegrityResponse returns list of deleted entities when the response contains multiple entities',
    () {
      const integrityDoc = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <entities>
        <entity id="1">
            <deleted>true</deleted>
        </entity>
        <entity id="2">
            <deleted>true</deleted>
        </entity>
    </entities>
</data>''';
      final response = parser.parseIntegrityResponse(
        getXmlDocument(integrityDoc),
      )!;
      expect(response.length, 2);
      expect(response[0].id, '1');
      expect(response[0].deleted, true);
      expect(response[1].id, '2');
      expect(response[1].deleted, true);
    },
  );

  test(
    '#parseIntegrityResponse returns an empty list if the response has no entities',
    () {
      const integrityDoc = '''
<?xml version="1.0" encoding="UTF-8"?>
<data>
    <entities>

    </entities>
</data>''';
      final response = parser.parseIntegrityResponse(
        getXmlDocument(integrityDoc),
      )!;
      expect(response, isEmpty);
    },
  );

  group('form list (not in Collect)', () {
    test('reads every field and skips extensions', () {
      const response = '''
<xforms xmlns="http://openrosa.org/xforms/xformsList" xmlns:x="urn:other">
  <xform>
    <formID>one</formID>
    <name>The First Form</name>
    <majorMinorVersion>1.0</majorMinorVersion>
    <version>  </version>
    <hash>md5:b71c92bec48730119eab982044a8adff</hash>
    <descriptionText>d</descriptionText>
    <downloadUrl>https://example.com/formXml?formId=one</downloadUrl>
    <manifestUrl>https://example.com/manifest?formId=one</manifestUrl>
    <x:formID>ignored</x:formID>
  </xform>
  <x:xform><formID>no</formID></x:xform>
  <XFORM>
    <formID>two</formID>
    <name>Two</name>
    <version>2</version>
    <downloadUrl>https://example.com/two</downloadUrl>
  </XFORM>
</xforms>''';
      expect(parser.parseFormList(getXmlDocument(response)), [
        const FormListItem(
          downloadUrl: 'https://example.com/formXml?formId=one',
          formId: 'one',
          name: 'The First Form',
          hash: 'b71c92bec48730119eab982044a8adff',
          manifestUrl: 'https://example.com/manifest?formId=one',
        ),
        const FormListItem(
          downloadUrl: 'https://example.com/two',
          formId: 'two',
          name: 'Two',
          version: '2',
        ),
      ]);
    });

    test('returns null when a form lacks a required field', () {
      const response = '''
<xforms xmlns="http://openrosa.org/xforms/xformsList">
  <xform><formID>one</formID><name>One</name><downloadUrl>u</downloadUrl></xform>
  <xform><formID>two</formID><name></name><downloadUrl>u</downloadUrl></xform>
</xforms>''';
      expect(parser.parseFormList(getXmlDocument(response)), isNull);
    });

    test('returns null for another root or namespace', () {
      expect(parser.parseFormList(getXmlDocument('<xforms/>')), isNull);
      expect(
        parser.parseFormList(
          getXmlDocument(
            '<forms xmlns="http://openrosa.org/xforms/xformsList"/>',
          ),
        ),
        isNull,
      );
    });

    test('namespaces are compared ignoring case', () {
      expect(
        parser.parseFormList(
          getXmlDocument(
            '<xforms xmlns="HTTP://openrosa.org/xforms/xformsList"/>',
          ),
        ),
        isEmpty,
      );
    });
  });
}
