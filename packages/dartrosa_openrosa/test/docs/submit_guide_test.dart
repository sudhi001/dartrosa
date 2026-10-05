// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// The code of docs/guides/encrypt-and-submit.md, run against a mock
// OpenRosa server so the guide can't rot (packages/dartrosa/test/docs
// checks that the guide's snippets are here).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_openrosa/dartrosa_openrosa.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// The public key of dartrosa_encryption's test key pair.
const publicKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs8otxEg8hXBynbFR1lSMbIQRfS/8/v0RbyHAD8K6BnZlVSSIOhPTBQKqeFhxyT6xDk5bT5Qk4VGhiEdMcqRouyqgNCXhx4v/IoCgoPwr2RE6boUD5TXDfVzc8x9wECon3NH2/PgtTg+15+D5ypkhF7VFm+50PePWrRJKSm5SFrymKhZuser9ShBFXmmxmILvs+RT8iZq4QrCW48dFz9vRVmLrRw0FSn6VWUOW9VTdRPtJHVl7obw3ZfhAj56sMyajEpZZR79ok1OmXMsETO3jcFoGV+Hn09P6fsqmuDJhkstOtfMhIWAEonlg+35cz8nsm3m30OoElqo5vCa/EfWcwIDAQAB';

const formXml =
    '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa">
  <h:head>
    <h:title>Household</h:title>
    <model>
      <instance>
        <data id="household" version="3">
          <name/><photo/><meta><instanceID/></meta>
        </data>
      </instance>
      <bind nodeset="/data/name" type="string"/>
      <bind nodeset="/data/photo" type="binary"/>
      <bind nodeset="/data/meta/instanceID" type="string" readonly="true()"
          jr:preload="uid"/>
      <submission base64RsaPublicKey="$publicKey"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/name"><label>Name</label></input>
    <upload ref="/data/photo" mediatype="image/*"><label>Photo</label></upload>
  </h:body>
</h:html>''';

const _server = 'https://central.example.org/v1/key/TOKEN/projects/1';

/// A fake ODK Central: form list, form, manifest, media and submissions.
MockClient fakeCentral(List<http.Request> requests) => MockClient((
  request,
) async {
  requests.add(request);
  const openRosa = {
    'x-openrosa-version': '1.0',
    'content-type': 'text/xml; charset=utf-8',
  };
  final path = request.url.path;
  if (path.endsWith('/formList')) {
    return http.Response(
      '''
<xforms xmlns="http://openrosa.org/xforms/xformsList">
  <xform>
    <formID>household</formID><name>Household</name><version>3</version>
    <hash>md5:00000000000000000000000000000000</hash>
    <downloadUrl>$_server/forms/household.xml</downloadUrl>
    <manifestUrl>$_server/forms/household/manifest</manifestUrl>
  </xform>
</xforms>''',
      200,
      headers: openRosa,
    );
  }
  if (path.endsWith('/household.xml')) {
    return http.Response.bytes(utf8.encode(formXml), 200, headers: openRosa);
  }
  if (path.endsWith('/manifest')) {
    return http.Response(
      '''
<manifest xmlns="http://openrosa.org/xforms/xformsManifest">
  <mediaFile>
    <filename>towns.csv</filename>
    <hash>md5:00000000000000000000000000000000</hash>
    <downloadUrl>$_server/forms/household/towns.csv</downloadUrl>
  </mediaFile>
</manifest>''',
      200,
      headers: openRosa,
    );
  }
  if (path.endsWith('/towns.csv')) {
    return http.Response('name,label\nnbo,Nairobi\n', 200, headers: openRosa);
  }
  if (path.endsWith('/submission')) {
    if (request.method == 'HEAD') {
      return http.Response('', 204, headers: openRosa);
    }
    return http.Response(
      '<OpenRosaResponse xmlns="http://openrosa.org/http/response">'
      '<message nature="submit_success">Thanks!</message>'
      '</OpenRosaResponse>',
      201,
      headers: openRosa,
    );
  }
  return http.Response('', 404, headers: openRosa);
});

void main() {
  test('download, fill, encrypt and submit', () async {
    final requests = <http.Request>[];
    final httpClient = fakeCentral(requests);
    final savedMedia = <String, Uint8List>{};

    const serverUrl = 'https://central.example.org/v1/key/TOKEN/projects/1';

    final connection = HttpClientConnection(
      client: httpClient, // an http.Client
      fileToContentTypeMapper: CollectThenSystemContentTypeMapper(),
      userAgent: 'my-app/1.0',
    );
    final credentials = WebCredentialsUtils(
      // ODK Central app users and public links carry their token in the
      // URL; for a username and password, pass username: and password:.
      InMemoryServerCredentialsSettings(serverUrl: serverUrl),
    );
    final client = OpenRosaClient(
      serverUrl,
      connection,
      credentials,
      deviceId: 'my-app:device-1',
    );

    String? downloadedXml;
    for (final form in await client.fetchFormList()) {
      // form.formId, form.version and form.hash tell what changed.
      final xml = await utf8.decodeStream(
        await client.fetchForm(form.downloadUrl),
      );
      final manifest = await client.fetchManifest(form.manifestUrl);
      for (final file in manifest?.mediaFiles ?? const <MediaFile>[]) {
        // Skip files whose file.hash you already have.
        final bytes = await client.fetchMediaFile(file.downloadUrl);
        savedMedia[file.filename] = Uint8List.fromList(
          await bytes.expand((chunk) => chunk).toList(),
        );
      }
      downloadedXml = xml;
    }
    expect(savedMedia.keys, ['towns.csv']);

    final definition = await FormDefinition.parse(downloadedXml!);
    final session = definition.createSession();
    final name = session.root.children.first as QuestionNode;
    session.answer(name.index, const StringValue('Amina'));
    final photoBytes = Uint8List.fromList([1, 2, 3]);

    String? message;
    if (session.finalize() case FinalizeSuccess(:final submission)) {
      // Encrypted when the form has a base64RsaPublicKey, plain otherwise.
      final upload = InstanceUpload.forForm(
        definition.formDef,
        submission,
        attachments: {'photo.jpg': photoBytes}, // file name -> bytes
      );
      final uploader = OpenRosaInstanceUploader(connection, credentials);
      try {
        message = await uploader.uploadOneSubmission(
          upload,
          serverUrl: serverUrl,
          deviceId: 'my-app:device-1',
        );
      } on FormUploadAuthRequestedException {
        // Ask for a username and password, save them in the credentials
        // settings and try again.
      } on FormUploadException catch (e) {
        // Keep the submission and retry later; e.message says why.
        fail(e.message);
      }
    }

    expect(message, 'Thanks!');
    final post = requests.last;
    expect(post.method, 'POST');
    final body = latin1.decode(post.bodyBytes);
    expect(body, contains('submission.xml.enc'));
    expect(body, isNot(contains('Amina')));
  });

  test('encrypting without uploading', () async {
    final definition = await FormDefinition.parse(formXml);
    final session = definition.createSession();
    final submission = (session.finalize() as FinalizeSuccess).submission;
    final photoBytes = Uint8List.fromList([1, 2, 3]);

    final files = {'photo.jpg': photoBytes}; // file name -> bytes
    final encrypted = encryptSubmission(
      utf8.encode(submission.xml),
      files,
      definition.formDef,
    );
    // null when the form is not encrypted. Otherwise send
    // encrypted.manifestBytes as submission.xml, plus
    // encrypted.encryptedFiles (submission.xml.enc, photo.jpg.enc).

    expect(encrypted!.encryptedFiles.keys, {
      'photo.jpg.enc',
      'submission.xml.enc',
    });
  });
}
