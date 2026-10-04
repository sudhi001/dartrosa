// Port of JavaRosa v6.0.0 RecordAudioActionTest.
//
// JavaRosa's listener is static (`RecordAudioActions`); DartRosa's is
// `FormDef.recordAudioListener`, so it is set between parsing and
// initializing the form.
import 'package:dartrosa/src/codec/form_def_codec.dart';
import 'package:dartrosa/src/model/form_def.dart';
import 'package:dartrosa/src/model/instance/tree_reference.dart';
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

/// Port of `CapturingRecordAudioActionListener`.
final class CapturingRecordAudioActionListener {
  TreeReference? absoluteTargetRef;
  String? quality;

  void call(TreeReference absoluteTargetRef, String? quality) {
    this.absoluteTargetRef = absoluteTargetRef;
    this.quality = quality;
  }
}

/// `Scenario.init` with [listener] registered before initialization.
Future<Scenario> initWithListener(
  XFormsElement form,
  CapturingRecordAudioActionListener listener,
) async {
  final FormDef formDef = await XFormParser().parse(form.asXml());
  formDef.recordAudioListener = listener.call;
  return Scenario.fromFormDef(formDef);
}

void main() {
  test('recordAudioAction_isProcessedOnFormParse', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Record audio form'),
          model([
            mainInstance([
              t('data id="record-audio-form"', [t('recording'), t('q1')]),
            ]),
            t(
              'odk:recordaudio event="odk-instance-load" ref="/data/recording"',
            ),
          ]),
        ]),
        body([input('/data/q1')]),
      ),
    );

    expect(scenario.formDef.hasAction('recordaudio'), isTrue);
  });

  test('recordAudioAction_callsListenerActionTriggeredWhenTriggered', () async {
    final listener = CapturingRecordAudioActionListener();

    await initWithListener(
      html(
        head([
          title('Record audio form'),
          model([
            mainInstance([
              t('data id="record-audio-form"', [t('recording'), t('q1')]),
            ]),
            t(
              'odk:recordaudio event="odk-instance-load" '
              'ref="/data/recording" odk:quality="foo"',
            ),
          ]),
        ]),
        body([input('/data/q1')]),
      ),
      listener,
    );

    expect(listener.absoluteTargetRef, getRef('/data/recording'));
    expect(listener.quality, 'foo');
  });

  test('targetReferenceInRepeat_isContextualized', () async {
    final listener = CapturingRecordAudioActionListener();

    await initWithListener(
      html(
        head([
          title('Record audio form'),
          model([
            mainInstance([
              t('data id="record-audio-form"', [
                t('repeat', [t('recording'), t('q1')]),
              ]),
            ]),
          ]),
        ]),
        body([
          repeat('/data/repeat', [
            t(
              'odk:recordaudio event="odk-instance-load" '
              'ref="/data/repeat/recording"',
            ),
            input('/data/repeat/q1'),
          ]),
        ]),
      ),
      listener,
    );

    expect(listener.absoluteTargetRef, getRef('/data/repeat[1]/recording'));
  });

  test('serializationAndDeserialization_maintainsFields', () async {
    final scenario = await Scenario.init(
      html(
        head([
          title('Record audio form'),
          model([
            mainInstance([
              t('data id="record-audio-form"', [t('recording'), t('q1')]),
            ]),
            t(
              'odk:recordaudio event="odk-instance-load" '
              'ref="/data/recording" odk:quality="foo"',
            ),
          ]),
        ]),
        body([input('/data/q1')]),
      ),
    );

    final listener = CapturingRecordAudioActionListener();

    // scenario.serializeAndDeserializeForm(), with the listener set on the
    // restored form before it is initialized.
    final restored = await FormDefCodec.decode(
      FormDefCodec.encode(scenario.formDef),
    );
    restored.recordAudioListener = listener.call;
    Scenario.fromFormDef(restored, newInstance: false);

    expect(listener.absoluteTargetRef, getRef('/data/recording'));
    expect(listener.quality, 'foo');
  });
}
