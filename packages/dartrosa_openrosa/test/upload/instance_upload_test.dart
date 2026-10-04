// InstanceUpload from a DartRosa FormSession submission, plain and
// encrypted with dartrosa_encryption.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:test/test.dart';

import '../support/mock_web_server.dart';

/// The public key of dartrosa_encryption's test key pair.
const testPublicKeyBase64 =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs8otxEg8hXBynbFR1lSMbIQRfS/8/v0RbyHAD8K6BnZlVSSIOhPTBQKqeFhxyT6xDk5bT5Qk4VGhiEdMcqRouyqgNCXhx4v/IoCgoPwr2RE6boUD5TXDfVzc8x9wECon3NH2/PgtTg+15+D5ypkhF7VFm+50PePWrRJKSm5SFrymKhZuser9ShBFXmmxmILvs+RT8iZq4QrCW48dFz9vRVmLrRw0FSn6VWUOW9VTdRPtJHVl7obw3ZfhAj56sMyajEpZZR79ok1OmXMsETO3jcFoGV+Hn09P6fsqmuDJhkstOtfMhIWAEonlg+35cz8nsm3m30OoElqo5vCa/EfWcwIDAQAB';

String form({String submission = ''}) =>
    '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms">
  <h:head>
    <h:title>Upload</h:title>
    <model>
      <instance>
        <data id="upload-form" version="3">
          <name/>
          <photo/>
          <meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string"/>
      <bind nodeset="/data/photo" type="binary"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()" jr:preload="uid"/>
      $submission
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Name</label></input>
    <upload ref="/data/photo" mediatype="image/*"><label>Photo</label></upload>
  </h:body>
</h:html>''';

final class FilePointer implements DataPointer {
  FilePointer(this.displayText);

  @override
  final String displayText;
}

Future<(FormDefinition, Submission)> finalize(String xml) async {
  final definition = await FormDefinition.parse(xml);
  final session = definition.createSession();
  session.navigator.next();
  expect(
    session.answer(session.navigator.position, const StringValue('Zoë')),
    isA<AnswerAccepted>(),
  );
  session.navigator.next();
  expect(
    session.answer(
      session.navigator.position,
      PointerValue(FilePointer('photo.jpg')),
    ),
    isA<AnswerAccepted>(),
  );
  final result = session.finalize();
  return (definition, (result as FinalizeSuccess).submission);
}

String text(UploadFile f) => utf8.decode((f as BytesUploadFile).bytes);

void main() {
  final photo = Uint8List.fromList(List.generate(100, (i) => i));

  test('fromSubmission uploads the XML and the attachments', () async {
    final (_, submission) = await finalize(form());
    expect(submission.attachments, ['photo.jpg']);
    final upload = InstanceUpload.fromSubmission(
      submission,
      attachments: {'photo.jpg': photo},
      instanceFileName: 'Upload_2026-10-04_10-00-00.xml',
      submissionUri: 'https://s.org/submission',
    );
    expect(upload.instanceFileName, 'Upload_2026-10-04_10-00-00.xml');
    expect(upload.files.map((f) => f.name), [
      'Upload_2026-10-04_10-00-00.xml',
      'photo.jpg',
    ]);
    expect(text(upload.files.first), submission.xml);
    expect(upload.submissionUri, 'https://s.org/submission');
  });

  test('forForm uses the form submission URL, unencrypted', () async {
    final (definition, submission) = await finalize(
      form(
        submission: '<submission action="https://s.org/custom" method="post"/>',
      ),
    );
    final upload = InstanceUpload.forForm(
      definition.formDef,
      submission,
      attachments: {'photo.jpg': photo},
    );
    expect(upload.submissionUri, 'https://s.org/custom');
    expect(upload.instanceFileName, 'submission.xml');
    expect(upload.files.map((f) => f.name), ['submission.xml', 'photo.jpg']);
    expect(text(upload.files.first), contains('<name>Zoë</name>'));
  });

  test('forForm encrypts when the form has a public key', () async {
    final (definition, submission) = await finalize(
      form(
        submission:
            '<submission base64RsaPublicKey="$testPublicKeyBase64" '
            'orx:auto-send="false"/>',
      ),
    );
    final upload = InstanceUpload.forForm(
      definition.formDef,
      submission,
      attachments: {'photo.jpg': photo},
    );
    expect(upload.submissionUri, isNull);
    expect(upload.instanceFileName, 'submission.xml');
    expect(upload.files.map((f) => f.name), [
      'submission.xml',
      'photo.jpg.enc',
      'submission.xml.enc',
    ]);
    final manifest = text(upload.files.first);
    expect(manifest, contains('encrypted="yes"'));
    expect(manifest, contains(submission.instanceId));
    expect(submission.instanceId, startsWith('uuid:'));
    expect(manifest, isNot(contains('Zoë')));
  });

  test('an encrypted upload goes through the uploader', () async {
    final (definition, submission) = await finalize(
      form(
        submission: '<submission base64RsaPublicKey="$testPublicKeyBase64"/>',
      ),
    );
    final server = MockWebServer('https://s.org')
      ..enqueue(MockResponse(code: 204))
      ..enqueue(MockResponse(code: 201));
    await OpenRosaInstanceUploader(
      HttpClientConnection(
        client: server.client,
        fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
        userAgent: 'test',
      ),
      WebCredentialsUtils(InMemoryServerCredentialsSettings()),
    ).uploadOneSubmission(
      InstanceUpload.forForm(
        definition.formDef,
        submission,
        attachments: {'photo.jpg': photo},
      ),
      serverUrl: 'https://s.org',
    );
    server.takeRequest();
    final parts = splitMultiPart(server.takeRequest());
    expect(parts.length, 3);
    expect(parts[0][1], contains('filename="submission.xml"'));
    expect(parts[1][1], contains('name="photo.jpg.enc"'));
    expect(parts[1][2], 'Content-Type: application/octet-stream');
    expect(parts[2][1], contains('name="submission.xml.enc"'));
  });
}
