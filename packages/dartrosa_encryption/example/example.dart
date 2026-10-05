// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

// Finalizes an encrypted form and encrypts its submission the way ODK
// Collect does (decryptable by ODK Central and ODK Briefcase with the
// matching private key).
import 'dart:convert';

import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';

// A test RSA public key; use the key of your form in ODK Central.
const publicKey =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAs8otxEg8hXBynbFR1lSMbIQRfS'
    '/8/v0RbyHAD8K6BnZlVSSIOhPTBQKqeFhxyT6xDk5bT5Qk4VGhiEdMcqRouyqgNCXhx4v/'
    'IoCgoPwr2RE6boUD5TXDfVzc8x9wECon3NH2/PgtTg+15+D5ypkhF7VFm+50PePWrRJKSm'
    '5SFrymKhZuser9ShBFXmmxmILvs+RT8iZq4QrCW48dFz9vRVmLrRw0FSn6VWUOW9VTdRPt'
    'JHVl7obw3ZfhAj56sMyajEpZZR79ok1OmXMsETO3jcFoGV+Hn09P6fsqmuDJhkstOtfMhI'
    'WAEonlg+35cz8nsm3m30OoElqo5vCa/EfWcwIDAQAB';

const xform =
    '''
<h:html xmlns="http://www.w3.org/2002/xforms"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns:jr="http://openrosa.org/javarosa"
    xmlns:orx="http://openrosa.org/xforms">
  <h:head>
    <h:title>Secret survey</h:title>
    <model>
      <instance>
        <data id="secret" version="1"><answer/><meta><instanceID/></meta></data>
      </instance>
      <bind nodeset="/data/answer" type="string"/>
      <bind nodeset="/data/meta/instanceID" type="string" jr:preload="uid"/>
      <submission base64RsaPublicKey="$publicKey" method="post"/>
    </model>
  </h:head>
  <h:body>
    <input ref="/data/answer"><label>Answer</label></input>
  </h:body>
</h:html>
''';

Future<void> main() async {
  final definition = await FormDefinition.parse(xform);
  final session = definition.createSession();
  final answer = session.root.children.whereType<QuestionNode>().single;
  session.answer(answer.index, const StringValue('confidential'));

  if (session.finalize() case FinalizeSuccess(:final submission)) {
    final encrypted = encryptSubmission(
      utf8.encode(submission.xml),
      const {}, // attachments: file name -> bytes
      definition.formDef,
    );
    if (encrypted != null) {
      _log(encrypted.manifest); // upload as xml_submission_file
      _log('encrypted files: ${encrypted.encryptedFiles.keys}');
    }
  }
}

// ignore: avoid_print
void _log(Object? message) => print(message);
