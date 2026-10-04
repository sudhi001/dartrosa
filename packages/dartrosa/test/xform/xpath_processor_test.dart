// Port of JavaRosa v6.0.0 XPathProcessorTest.
import 'package:dartrosa/src/xform/xform_parser.dart';
import 'package:dartrosa/src/xpath/expression.dart';
import 'package:dartrosa/src/xpath/qname.dart';
import 'package:dartrosa/testing.dart';
import 'package:test/test.dart';

final class RecordingXPathProcessor implements XPathProcessor {
  final List<XPathExpression> processedExpressions = [];

  @override
  void processXPath(XPathExpression expression) =>
      processedExpressions.add(expression);
}

String formXml() => html(
  head([
    model([
      mainInstance([
        t('data id="form"', [t('question')]),
      ]),
      bind('/data/question')..type('string'),
    ]),
  ]),
  body([input('/data/question')]),
).asXml();

void main() {
  test('processes XPath expressions', () async {
    final processor = RecordingXPathProcessor();
    await (XFormParser()..addProcessor(processor)).parse(formXml());
    final dataQuestion = XPathPathExpr(PathStart.root, [
      XPathStep.named(XPathAxis.child, XPathQName(null, 'data')),
      XPathStep.named(XPathAxis.child, XPathQName(null, 'question')),
    ]);
    expect(processor.processedExpressions, [dataQuestion, dataQuestion]);
  });

  test('processors are not retained between parses', () async {
    final processor = RecordingXPathProcessor();
    await (XFormParser()..addProcessor(processor)).parse(formXml());
    expect(processor.processedExpressions, hasLength(2));
    await XFormParser().parse(formXml());
    expect(processor.processedExpressions, hasLength(2));
  });
}
