// Copyright 2026 The DartRosa Authors
// Derived from JavaRosa (XFormParser, RangeParser, XPathReference), Copyright
//  (C) 2009 JavaRosa; modified: translated to Dart.
// SPDX-License-Identifier: Apache-2.0

import 'package:logging/logging.dart';

import '../i18n/locale_source.dart';
import '../i18n/localizer.dart';
import '../model/actions/actions.dart';
import '../model/condition/conditions.dart';
import '../model/control_type.dart';
import '../model/data_binding.dart';
import '../model/form_def.dart';
import '../model/form_element.dart';
import '../model/instance/external/external_instance_parser.dart';
import '../model/instance/external_data_instance.dart';
import '../model/instance/tree_reference.dart';
import '../model/itemset_binding.dart';
import '../model/select_choice.dart';
import '../model/submission_profile.dart';
import '../reference/resource_resolver.dart';
import '../util/java_lang.dart';
import '../util/randomize.dart';
import '../xpath/exceptions.dart';
import '../xpath/expression.dart';
import '../xpath/parser.dart';
import 'bind_attributes.dart';
import 'form_instance_parser.dart';
import 'instance_loading.dart';
import 'instance_structure.dart';
import 'kdom.dart';
import 'xform_parse_exception.dart';

export 'bind_attributes.dart' show BindAttributeProcessor;

final _log = Logger('dartrosa.xform');

/// The ODK namespace.
const namespaceOdk = 'http://www.opendatakit.org/xforms';

/// The XHTML namespace.
const namespaceHtml = 'http://www.w3.org/1999/xhtml';

const _itextOpen = "jr:itext('";
const _itextClose = "')";
const _dynamicItextOpen = 'jr:itext(';
const _dynamicItextClose = ')';

/// Called for model attributes it declares. Port of
/// `XFormParser.ModelAttributeProcessor`.
abstract interface class ModelAttributeProcessor {
  /// The (namespace, name) pairs this processor handles.
  Set<(String, String)> get modelAttributes;

  /// Handles one model attribute.
  void processModelAttribute(String name, String value);
}

/// Called for every parsed question. Port of
/// `XFormParser.QuestionProcessor`.
abstract interface class QuestionProcessor {
  /// Handles [question].
  void processQuestion(QuestionDef question);
}

/// Called with the finished form. Port of `XFormParser.FormDefProcessor`.
abstract interface class FormDefProcessor {
  /// Handles [form].
  void processFormDef(FormDef form);
}

/// Called for every XPath expression parsed from the form. Port of
/// `XFormParser.XPathProcessor`.
abstract interface class XPathProcessor {
  /// Handles [expression].
  void processXPath(XPathExpression expression);
}

/// Called for every external secondary instance. Port of
/// `XFormParser.ExternalDataInstanceProcessor`.
abstract interface class ExternalDataInstanceProcessor {
  /// Handles [instance].
  void processInstance(ExternalDataInstance instance);
}

/// Handles an action element on its parent form element.
typedef ActionElementHandler =
    void Function(XFormParser parser, KElement element, FormElement parent);

/// Parses an XForm into a [FormDef].
///
/// Port of `org.javarosa.xform.parse.XFormParser`. Everything JavaRosa
/// keeps in static registries (action handlers, processors) is configured
/// per parser. Parsing is asynchronous only because external secondary
/// instances are read through a [ResourceResolver].
final class XFormParser {
  /// Creates a parser reading `jr://` resources through [resolver].
  XFormParser({
    ResourceResolver? resolver,
    ExternalInstanceParser? externalInstanceParser,
    SetGeopointAction Function(TreeReference target)? setGeopointAction,
  }) : _resolver = resolver ?? MapResourceResolver(const {}),
       _externalInstanceParser =
           externalInstanceParser ?? ExternalInstanceParser(),
       _setGeopointAction = setGeopointAction ?? StubSetGeopointAction.new {
    registerActionHandler(SetValueAction.elementName, (p, e, parent) {
      p._parseSetValueAction(parent.actionController, e);
    });
    registerActionHandler(SetGeopointAction.elementName, _parseSetGeopoint);
    registerActionHandler(RecordAudioAction.elementName, _parseRecordAudio);
  }

  final ResourceResolver _resolver;
  final ExternalInstanceParser _externalInstanceParser;
  final SetGeopointAction Function(TreeReference target) _setGeopointAction;
  final Map<String, ActionElementHandler> _actionHandlers = {};

  final List<BindAttributeProcessor> _bindAttributeProcessors = [];
  final List<FormDefProcessor> _formDefProcessors = [];
  final List<ModelAttributeProcessor> _modelAttributeProcessors = [];
  final List<QuestionProcessor> _questionProcessors = [];
  final List<XPathProcessor> _xpathProcessors = [];
  final List<ExternalDataInstanceProcessor> _externalInstanceProcessors = [];
  final List<void Function(String warning)> _warningCallbacks = [];
  final List<void Function(String error)> _errorCallbacks = [];

  // Per-parse state.
  late FormDef _f;
  var _modelFound = false;
  Localizer? _localizer;
  final Map<String, DataBinding> _bindingsById = {};
  final List<DataBinding> _bindings = [];
  final List<TreeReference> _actionTargets = [];
  final List<TreeReference> _repeats = [];
  final List<ItemsetBinding> _itemsets = [];
  final List<TreeReference> _selectOnes = [];
  final List<TreeReference> _multipleItems = [];
  KElement? _mainInstanceNode;
  final List<KElement> _instanceNodes = [];
  final List<String?> _instanceNodeIds = [];
  final List<String> _itextKnownForms = [];
  final Set<String> _referencedInstanceIds = {};
  var _serialQuestionId = 1;

  /// Adds a plugin [processor]: any of [BindAttributeProcessor],
  /// [FormDefProcessor], [ModelAttributeProcessor], [QuestionProcessor],
  /// [XPathProcessor] or [ExternalDataInstanceProcessor].
  void addProcessor(Object processor) {
    if (processor is BindAttributeProcessor) {
      _bindAttributeProcessors.add(processor);
    }
    if (processor is FormDefProcessor) _formDefProcessors.add(processor);
    if (processor is ModelAttributeProcessor) {
      _modelAttributeProcessors.add(processor);
    }
    if (processor is QuestionProcessor) _questionProcessors.add(processor);
    if (processor is XPathProcessor) _xpathProcessors.add(processor);
    if (processor is ExternalDataInstanceProcessor) {
      _externalInstanceProcessors.add(processor);
    }
  }

  /// Registers [handler] for action elements called [name] (local name);
  /// it runs after the generic event checks.
  void registerActionHandler(String name, ActionElementHandler handler) {
    _actionHandlers[name] = (p, e, parent) =>
        p._parseAction(e, parent, handler);
  }

  /// Receives each parse warning.
  void onWarning(void Function(String warning) callback) =>
      _warningCallbacks.add(callback);

  /// Receives each non-fatal parse error.
  void onError(void Function(String error) callback) =>
      _errorCallbacks.add(callback);

  /// Parses [formXml]. [lastSavedSrc] is the `src` to use for
  /// `jr://instance/last-saved`. With [instanceXml] (a saved instance),
  /// its answers replace the blank instance (typed by [answerResolver]).
  ///
  /// [restoringCachedForm] re-parses a form that parsed before (see
  /// `FormDefCodec`) the way JavaRosa's `readExternal` restores one: a
  /// missing external secondary instance file throws
  /// [ResourceNotFoundException] instead of being replaced by a
  /// placeholder, and itemset label and value nodes in external instances
  /// are not verified (deserialization does no parse-time verification).
  Future<FormDef> parse(
    String formXml, {
    String? formXmlSrc,
    String? lastSavedSrc,
    String? instanceXml,
    AnswerResolver answerResolver = defaultAnswerResolver,
    bool restoringCachedForm = false,
  }) async {
    final root = getXmlDocument(formXml);
    await _parseDoc(
      root,
      formXmlSrc,
      lastSavedSrc,
      restoringCachedForm: restoringCachedForm,
    );
    _f
      ..sourceXml = formXml
      ..lastSavedSrc = lastSavedSrc;
    if (instanceXml != null) {
      _f.loadXmlInstance(instanceXml, resolver: answerResolver);
    }
    for (final processor in _formDefProcessors) {
      processor.processFormDef(_f);
    }
    return _f;
  }

  void _initState() {
    _modelFound = false;
    _localizer = null;
    _bindingsById.clear();
    _bindings.clear();
    _actionTargets.clear();
    _repeats.clear();
    _itemsets.clear();
    _selectOnes.clear();
    _multipleItems.clear();
    _mainInstanceNode = null;
    _instanceNodes.clear();
    _instanceNodeIds.clear();
    _itextKnownForms
      ..clear()
      ..addAll(['long', 'short', 'image', 'audio']);
    _referencedInstanceIds.clear();
  }

  Future<void> _parseDoc(
    KElement root,
    String? formXmlSrc,
    String? lastSavedSrc, {
    required bool restoringCachedForm,
  }) async {
    _f = FormDef()..formXmlPath = formXmlSrc;
    _initState();
    final defaultNamespace = root.namespaceDeclarations
        .where((d) => d.$1 == null)
        .map((d) => d.$2)
        .firstOrNull;
    final namespacePrefixesByUri = namespacesMap(root);
    _parseElement(root, _f, topLevel: true);
    _collapseRepeatGroups(_f);
    final instanceParser = FormInstanceParser(
      _f,
      defaultNamespace,
      _bindings,
      _repeats,
      _itemsets,
      _selectOnes,
      _multipleItems,
      _actionTargets,
      verifyExternalItemsets: !restoringCachedForm,
    );

    // Secondary instances first; they shouldn't reference the main one.
    for (var i = 1; i < _instanceNodes.length; i++) {
      final instance = _instanceNodes[i];
      final instanceId = _instanceNodeIds[i];
      final src = _parseInstanceSrc(instance, lastSavedSrc);
      // Only instances used in an instance() call are loaded.
      if (!_referencedInstanceIds.contains(instanceId)) continue;
      if (src != null) {
        final ExternalDataInstance external;
        try {
          external = await ExternalDataInstance.build(
            _resolver,
            src,
            instanceId!,
            parser: _externalInstanceParser,
            placeholderIfMissing: !restoringCachedForm,
          );
          for (final processor in _externalInstanceProcessors) {
            processor.processInstance(external);
          }
        } on ResourceNotFoundException {
          rethrow;
        } on Exception catch (e) {
          throw XFormParseException(
            'Unable to parse external secondary instance: $e',
            instance,
          );
        }
        _f.addNonMainInstance(external);
      } else {
        final formInstance = instanceParser.parseInstance(
          instance,
          isMainInstance: false,
          name: instanceId,
          namespacePrefixesByUri: namespacePrefixesByUri,
        );
        loadNamespaces(root, formInstance);
        loadInstanceData(instance, formInstance.root, _f);
        _f.addNonMainInstance(formInstance);
      }
    }

    final mainNode = _mainInstanceNodeOrThrow();
    final formInstance = instanceParser.parseInstance(
      mainNode,
      isMainInstance: true,
      // The main instance is the first one saved.
      name: _instanceNodeIds.first,
      namespacePrefixesByUri: namespacePrefixesByUri,
    );
    // Keep the form's prefixes so serialization uses the same ones.
    loadNamespaces(root, formInstance);
    loadInstanceData(mainNode, formInstance.root, _f);
    _f
      ..mainInstance = formInstance
      ..localizer = _localizer;
    try {
      _f.finalizeTriggerables();
    } on StateError catch (e) {
      throw XFormParseException(
        e.message.isEmpty
            ? 'Form has an illegal cycle in its calculate and relevancy '
                  'expressions!'
            : e.message,
      );
    }

    for (final instance in _f.nonMainInstances.values) {
      instance.root
        ?..clearChildrenCaches()
        ..clearCaches();
    }
    _f.mainInstance.root
      ..clearChildrenCaches()
      ..clearCaches();
  }

  String? _parseInstanceSrc(KElement instance, String? lastSavedSrc) {
    final src = instance.attribute(null, 'src');
    if (src == null) return null;
    final lower = src.toLowerCase();
    if (lower.startsWith('jr://file/') || lower.startsWith('jr://file-csv/')) {
      return src;
    }
    if (lower == 'jr://instance/last-saved') return lastSavedSrc;
    _log.warning('Invalid instance `src`: $src');
    return null;
  }

  static const _validElementNames = {
    'html', 'head', 'body', 'xform', 'chooseCaption', 'addCaption', //
    'addEmptyCaption', 'delCaption', 'doneCaption', 'doneEmptyCaption',
    'mainHeader', 'entryHeader', 'delHeader',
  };

  /// Dispatches [e] to its handler (top-level handlers include `model`,
  /// `title` and `meta`); unknown elements are warned about and their
  /// children processed.
  void _parseElement(KElement e, FormElement parent, {required bool topLevel}) {
    switch (e.name) {
      case 'input':
        const passedThrough = ['rows', 'query'];
        _parseControl(
          parent,
          e,
          ControlType.input,
          passedThrough,
          passedThrough,
        );
      case 'range':
        _parseControl(parent, e, ControlType.range, ['start', 'end', 'step']);
      case 'secret':
        _parseControl(parent, e, ControlType.secret);
      case 'select':
        _parseControl(parent, e, ControlType.selectMulti);
      case 'rank':
        _parseControl(parent, e, ControlType.rank);
      case 'select1':
        _parseControl(parent, e, ControlType.selectOne);
      case 'group':
        _parseGroup(parent, e, isRepeat: false);
      case 'repeat':
        _parseGroup(parent, e, isRepeat: true);
      case 'trigger':
        _parseControl(parent, e, ControlType.trigger);
      case 'upload':
        _parseUpload(parent, e);
      case 'label':
        if (parent is! GroupDef) {
          throw XFormParseException('parent of element is not a group', e);
        }
        _parseGroupLabel(parent, e);
      case 'model' when topLevel:
        _parseModel(e);
      case 'title' when topLevel:
        _parseTitle(e);
      case 'meta' when topLevel:
        _parseMeta(e);
      default:
        if (!_validElementNames.contains(e.name)) {
          _triggerWarning(
            'Unrecognized element [${e.name}]. Ignoring and processing '
            'children...',
            vagueLocation(e),
          );
        }
        for (final child in e.childElements) {
          _parseElement(child, parent, topLevel: topLevel);
        }
    }
  }

  void _parseTitle(KElement e) {
    final title = xmlText(e, trim: true);
    _f.title = title;
    _f.name ??= title;
    _warnUnusedAttributes(e, const []);
  }

  void _parseMeta(KElement e) {
    for (final a in e.attributes) {
      if (a.name == 'name') _f.name = a.value;
    }
    _warnUnusedAttributes(e, const ['name']);
  }

  void _parseModel(KElement e) {
    for (final processor in _modelAttributeProcessors) {
      for (final a in e.attributes) {
        if (processor.modelAttributes.contains((a.namespace, a.name))) {
          processor.processModelAttribute(a.name, a.value);
        }
      }
    }
    if (_modelFound) {
      _triggerWarning(
        'Multiple models not supported. Ignoring subsequent models.',
        vagueLocation(e),
      );
      return;
    }
    _modelFound = true;
    _warnUnusedAttributes(e, const []);

    final delayed = <KElement>[];
    for (var i = 0; i < e.childCount; i++) {
      final child = e.elementAt(i);
      final name = child?.name;
      if (name == 'itext') {
        _parseIText(child!);
      } else if (name == 'instance') {
        _saveInstanceNode(child!);
      } else if (name == 'bind') {
        _parseBind(child!);
      } else if (name == 'submission' ||
          (name != null && _actionHandlers.containsKey(name))) {
        delayed.add(child!);
      } else if (child != null) {
        throw XFormParseException(
          'Unrecognized top-level tag [$name] found within <model>',
          child,
        );
      } else if (e.isText(i) && xmlText(e, trim: true, from: i)!.isNotEmpty) {
        throw XFormParseException(
          'Unrecognized text content found within <model>: '
          '"${xmlText(e, trim: true, from: i)}"',
          e,
        );
      }
    }
    for (final child in delayed) {
      if (child.name == 'submission') {
        _parseSubmission(child);
      } else if (child.attribute(null, 'event') == FormEvents.odkNewRepeat) {
        throw XFormParseException(
          'Actions triggered by ${FormEvents.odkNewRepeat} must be nested in '
          'the repeat form control.',
          child,
        );
      } else {
        _actionHandlers[child.name]!(this, child, _f);
      }
    }
  }

  void _parseAction(
    KElement e,
    FormElement parent,
    ActionElementHandler specificHandler,
  ) {
    for (final event in validEventNames(e.attribute(null, 'event'))) {
      if (!identical(parent, _f) && FormEvents.isTopLevel(event)) {
        _f.registerElementWithActionTriggeredByToplevelEvent(parent);
      }
    }
    _f.registerAction(e.name);
    specificHandler(this, e, parent);
  }

  /// The events in the space-separated [events]; throws for unsupported
  /// ones. Port of `XFormParser.getValidEventNames`.
  static List<String> validEventNames(String? events) {
    if (events == null) {
      // JavaRosa fails with a NullPointerException here.
      throw XFormParseException('An action was registered without events');
    }
    final valid = <String>[];
    final invalid = <String>[];
    for (final event in javaSplit(events, ' ')) {
      (FormEvents.isValid(event) ? valid : invalid).add(event);
    }
    if (invalid.isNotEmpty) {
      throw XFormParseException(
        'An action was registered for unsupported events: '
        '${invalid.join(', ')}',
      );
    }
    return valid;
  }

  /// Records a node an action sets (verified once the instance exists).
  void registerActionTarget(TreeReference target) => _actionTargets.add(target);

  void _parseSetValueAction(ActionController source, KElement e) {
    final ref = e.attribute(null, 'ref');
    final bind = e.attribute(null, 'bind');
    TreeReference target;
    if (bind != null) {
      final binding =
          _bindingsById[bind] ??
          (throw XFormParseException(
            "XForm Parse: invalid binding ID in submit'$bind'",
            e,
          ));
      target = binding.reference;
    } else if (ref != null) {
      target = FormDef.getAbsRef(_reference(ref), const TreeReference.root());
    } else {
      throw XFormParseException('setvalue action with no target!', e);
    }
    final valueExpression = e.attribute(null, 'value');
    registerActionTarget(target);
    final XPathExpression value;
    if (valueExpression == null) {
      value = XPathStringLiteral(
        e.childCount > 0 && e.isText(0) ? e.textAt(0)! : '',
      );
    } else if (valueExpression.isEmpty) {
      value = const XPathStringLiteral('');
    } else {
      try {
        value = _parseXPath(valueExpression);
      } on XPathSyntaxException {
        throw XFormParseException(
          "Invalid XPath in value set action declaration: '$valueExpression'",
          e,
        );
      }
    }
    source.registerEventListener(
      validEventNames(e.attribute(null, 'event')),
      SetValueAction(target, value),
    );
  }

  static void _parseSetGeopoint(XFormParser p, KElement e, FormElement parent) {
    if (e.namespace != namespaceOdk) {
      throw XFormParseException(
        'setgeopoint action must be in $namespaceOdk namespace',
      );
    }
    final ref =
        e.attribute(null, 'ref') ??
        (throw XFormParseException(
          'odk:setgeopoint action must specify a ref',
        ));
    final target = FormDef.getAbsRef(
      p._reference(ref),
      const TreeReference.root(),
    );
    p.registerActionTarget(target);
    parent.actionController.registerEventListener(
      validEventNames(e.attribute(null, 'event')),
      p._setGeopointAction(target),
    );
  }

  static void _parseRecordAudio(XFormParser p, KElement e, FormElement parent) {
    if (e.namespace != namespaceOdk) {
      throw XFormParseException(
        'recordaudio action must be in $namespaceOdk namespace',
      );
    }
    final quality = e.attribute(namespaceOdk, 'quality');
    final ref =
        e.attribute(null, 'ref') ??
        (throw XFormParseException(
          'odk:recordaudio action must specify a ref',
        ));
    final target = FormDef.getAbsRef(
      p._reference(ref),
      const TreeReference.root(),
    );
    p.registerActionTarget(target);
    final events = validEventNames(e.attribute(null, 'event'));
    for (final event in events) {
      if (!FormEvents.isInstanceLoad(event)) {
        throw XFormParseException(
          'odk:recordaudio action may only be triggered by instance load '
          'events (e.g. odk-instance-load)',
        );
      }
    }
    parent.actionController.registerEventListener(
      events,
      RecordAudioAction(target, quality),
    );
  }

  void _parseSubmission(KElement submission) {
    final id = submission.attribute(null, 'id');
    final method = submission.attribute(null, 'method');
    final action = submission.attribute(null, 'action');
    final ref = submission.attribute(null, 'ref');
    final bind = submission.attribute(null, 'bind');
    TreeReference dataRef;
    if (bind != null) {
      final binding =
          _bindingsById[bind] ??
          (throw XFormParseException(
            "XForm Parse: invalid binding ID in submit'$bind'",
            submission,
          ));
      dataRef = binding.reference;
    } else {
      dataRef = FormDef.getAbsRef(
        _reference(ref ?? '/'),
        const TreeReference.root(),
      );
    }
    final attributes = <String, String>{
      for (final a in submission.attributes)
        if (!const {'ref', 'bind', 'method', 'action'}.contains(a.name))
          a.name: a.value,
    };
    final profile = SubmissionProfile(
      dataRef,
      method,
      action,
      submission.attribute(null, 'mediatype'),
      attributes,
    );
    if (id == null) {
      _f.defaultSubmission = profile;
    } else {
      _f.addSubmissionProfile(id, profile);
    }
  }

  void _saveInstanceNode(KElement instance) {
    KElement? instanceNode;
    final instanceId = instance.attribute('', 'id');
    final instanceSrc = instance.attribute('', 'src');
    // Children are only considered when there is no src.
    if (instanceSrc == null) {
      for (final child in instance.childElements) {
        if (instanceNode != null) {
          throw XFormParseException(
            'XForm Parse: <instance> has more than one child element',
            instance,
          );
        }
        instanceNode = child;
      }
    }
    instanceNode ??= instance;
    _mainInstanceNode ??= instanceNode;
    _instanceNodes.add(instanceNode);
    _instanceNodeIds.add(instanceId);
  }

  void _processAdditionalAttributes(
    QuestionDef question,
    KElement e,
    List<String> usedAtts,
    List<String>? passedThrough,
  ) {
    for (final a in e.attributes) {
      if (!usedAtts.contains(a.name) ||
          (passedThrough != null && passedThrough.contains(a.name))) {
        question.setAdditionalAttribute(a.namespace, a.name, a.value);
      }
    }
    _warnUnusedAttributes(e, usedAtts);
  }

  void _parseUpload(FormElement parent, KElement e) {
    final mediaType = e.attribute(null, 'mediatype');
    final question = _parseControl(parent, e, ControlType.upload, [
      'mediatype',
    ]);
    question.controlType = switch (mediaType) {
      'image/*' => ControlType.imageChoose,
      'audio/*' => ControlType.audioCapture,
      'video/*' => ControlType.videoCapture,
      'osm/*' => ControlType.osmCapture,
      _ => ControlType.fileCapture,
    };
    if (mediaType == 'osm/*') question.osmTags = _parseOsmTags(e);
  }

  static List<OsmTag> _parseOsmTags(KElement e) {
    final tags = <OsmTag>[];
    for (final child in e.childElements) {
      if (child.name != 'tag') continue;
      final tag = OsmTag();
      tags.add(tag);
      for (final a in child.attributes) {
        if (a.name != 'key') continue;
        tag.key = a.value;
        for (final tagChild in child.childElements) {
          if (tagChild.name == 'label') {
            tag.label = tagChild.childCount == 0 ? null : tagChild.textAt(0);
          } else if (tagChild.name == 'item') {
            final item = OsmTagItem();
            tag.items.add(item);
            for (final itemChild in tagChild.childElements) {
              final text = itemChild.childCount == 0
                  ? null
                  : itemChild.textAt(0);
              if (itemChild.name == 'label') {
                item.label = text;
              } else if (itemChild.name == 'value') {
                item.value = text;
              }
            }
          }
        }
      }
    }
    return tags;
  }

  QuestionDef _parseControl(
    FormElement parent,
    KElement e,
    ControlType controlType, [
    List<String>? additionalUsedAtts,
    List<String>? passedThroughAtts,
  ]) {
    final question = controlType == ControlType.range
        ? RangeQuestion()
        : QuestionDef();
    question.id = _serialQuestionId++;
    final usedAtts = ['ref', 'bind', 'appearance', ...?additionalUsedAtts];
    final ref = e.attribute(null, 'ref');
    final bind = e.attribute(null, 'bind');
    TreeReference? dataRef;
    if (bind != null) {
      final binding =
          _bindingsById[bind] ??
          (throw XFormParseException(
            "XForm Parse: invalid binding ID '$bind'",
            e,
          ));
      dataRef = binding.reference;
    } else if (ref != null) {
      dataRef = _absoluteRef(_reference(ref), parent);
    } else if (controlType != ControlType.trigger) {
      throw XFormParseException(
        "XForm Parse: input control with neither 'ref' nor 'bind'",
        e,
      );
    }
    if (dataRef != null) {
      question.bind = dataRef;
      if (controlType == ControlType.selectOne) {
        _selectOnes.add(dataRef);
      } else if (controlType == ControlType.selectMulti ||
          controlType == ControlType.rank) {
        _multipleItems.add(dataRef);
      }
    }
    question
      ..controlType = controlType
      ..appearance = e.attribute(null, 'appearance');
    for (final child in e.childElements) {
      switch (child.name) {
        case 'label':
          _parseQuestionLabel(question, child);
        case 'hint':
          _parseHint(question, child);
        case 'item':
          _parseItem(question, child);
        case 'itemset':
          _parseItemset(question, child);
        default:
          _actionHandlers[child.name]?.call(this, child, question);
      }
    }
    if (controlType == ControlType.selectMulti ||
        controlType == ControlType.rank ||
        controlType == ControlType.selectOne) {
      if (question.numChoices > 0 && question.dynamicChoices != null) {
        throw XFormParseException(
          'Select question contains both literal choices and <itemset>',
        );
      } else if (question.numChoices == 0 && question.dynamicChoices == null) {
        throw XFormParseException(
          "Select question '${question.labelInnerText}' has no choices",
        );
      }
    }
    if (question is RangeQuestion) _populateRangeAttributes(question, e);
    parent.addChild(question);
    _processAdditionalAttributes(question, e, usedAtts, passedThroughAtts);
    for (final processor in _questionProcessors) {
      processor.processQuestion(question);
    }
    return question;
  }

  static final _bigDecimal = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

  /// Port of `RangeParser.populateQuestionWithRangeAttributes`; values are
  /// validated as Java `BigDecimal`s and kept as written.
  static void _populateRangeAttributes(RangeQuestion question, KElement e) {
    for (final a in e.attributes) {
      if (!const {
        'start',
        'end',
        'step',
        'tick-interval',
        'placeholder',
      }.contains(a.name)) {
        continue;
      }
      final ascii = String.fromCharCodes(
        a.value.codeUnits.map((c) {
          final d = javaDigit(c);
          return d >= 0 ? 0x30 + d : c;
        }),
      );
      if (!_bigDecimal.hasMatch(ascii)) {
        throw XFormParseException(
          "Value ${a.value} of range attribute ${a.name} can't be parsed as a "
          'decimal number',
        );
      }
      switch (a.name) {
        case 'start':
          question.rangeStart = a.value;
        case 'end':
          question.rangeEnd = a.value;
        case 'step':
          question.rangeStep = a.value;
        case 'tick-interval':
          question.tickInterval = a.value;
        case 'placeholder':
          question.placeholder = a.value;
      }
    }
  }

  void _parseQuestionLabel(QuestionDef q, KElement e) {
    final label = _label(e);
    final ref = e.attribute('', 'ref');
    if (ref != null) {
      q.textId = _itextRef(ref, 'Question <label>', '<label>');
    } else {
      q.labelInnerText = label;
    }
    _warnUnusedAttributes(e, const ['ref']);
  }

  void _parseGroupLabel(GroupDef g, KElement e) {
    // A <repeat>'s label comes from its wrapping <group>.
    if (g.isRepeat) return;
    final label = _label(e);
    final ref = e.attribute('', 'ref');
    if (ref != null) {
      g.textId = _itextRef(ref, 'Group <label>', '<label>');
    } else {
      g.labelInnerText = label;
    }
    _warnUnusedAttributes(e, const ['ref']);
  }

  /// The text id in `jr:itext('id')` [ref], verified to exist; a malformed
  /// [ref] is reported for [element] (located at [location] when given).
  String _itextRef(
    String ref,
    String type,
    String element, [
    KElement? location,
  ]) {
    if (!ref.startsWith(_itextOpen) || !ref.endsWith(_itextClose)) {
      throw XFormParseException('malformed ref [$ref] for $element', location);
    }
    final textRef = ref.substring(
      _itextOpen.length,
      ref.lastIndexOf(_itextClose),
    );
    _verifyTextMappings(textRef, type, allowSubforms: true);
    return textRef;
  }

  /// The inner text of a label-like element: `<output>`s become `${n}`,
  /// XHTML children are serialized, other elements dropped, comments and
  /// processing instructions read as `null` (as in JavaRosa); trimmed.
  String? _label(KElement e) {
    if (e.childCount == 0) return null;
    _recurseForOutput(e);
    final sb = StringBuffer();
    for (var i = 0; i < e.childCount; i++) {
      final child = e.children[i];
      if (child is KElement) {
        if (child.namespace == namespaceHtml) {
          sb.write(elementToString(child));
        } else {
          _log.info(
            'Unrecognized tag inside of text: <${child.name}>. Did you intend '
            'to use HTML markup? If so, ensure that the element is defined in '
            'the HTML namespace.',
          );
        }
      } else {
        sb.write(e.textAt(i));
      }
    }
    return javaTrim(sb.toString());
  }

  void _recurseForOutput(KElement e) {
    for (var i = 0; i < e.childCount; i++) {
      final kid = e.children[i];
      if (kid is! KElement) continue;
      if (kid.name.toLowerCase() == 'output') {
        final placeholder = '\${${_parseOutput(kid)}}';
        e
          ..removeChildAt(i)
          ..insertChild(i, KText(KNodeType.text, placeholder));
      } else if (kid.childCount != 0) {
        _recurseForOutput(kid);
      }
    }
  }

  String _parseOutput(KElement e) {
    final xpath =
        e.attribute(null, 'ref') ??
        e.attribute(null, 'value') ??
        (throw XFormParseException(
          "XForm Parse: <output> without 'ref' or 'value'",
          e,
        ));
    final XPathConditional expression;
    try {
      expression = _conditional(xpath);
    } on XPathSyntaxException catch (x) {
      _triggerError(
        'Invalid XPath expression in <output> [$xpath]! ${x.message}',
      );
      return '';
    }
    var index = _f.outputFragments.indexOf(expression);
    if (index == -1) {
      index = _f.outputFragments.length;
      _f.outputFragments.add(expression);
    }
    _warnUnusedAttributes(e, const ['ref', 'value']);
    return '$index';
  }

  void _parseHint(QuestionDef q, KElement e) {
    final hint = xmlText(e, trim: true);
    final hintInnerText = _label(e);
    final ref = e.attribute('', 'ref');
    if (ref != null) {
      q.helpTextId = _itextRef(ref, '<hint>', '<hint>');
    } else {
      q
        ..helpInnerText = hintInnerText
        ..helpText = hint;
    }
    _warnUnusedAttributes(e, const ['ref']);
  }

  static final _unsafeChoiceValueCharacter = RegExp('[ \n\t\f\r\'"`]');

  void _parseItem(QuestionDef q, KElement e) {
    const maxValueLength = 32;
    String? labelInnerText;
    String? textRef;
    String? value;
    for (final child in e.childElements) {
      if (child.name == 'label') {
        _warnUnusedAttributes(child, const ['ref']);
        labelInnerText = _label(child);
        final ref = child.attribute('', 'ref');
        if (ref != null) {
          textRef = _itextRef(ref, 'Item <label>', '<item>', child);
        }
      } else if (child.name == 'value') {
        value = xmlText(child, trim: true);
        _warnUnusedAttributes(child, const ['form']);
        if (value != null) {
          if (value.length > maxValueLength) {
            _triggerWarning(
              'choice value [$value] is too long; max. suggested length '
              '$maxValueLength chars',
              vagueLocation(child),
            );
          }
          if (value.contains(_unsafeChoiceValueCharacter)) {
            final type = switch (q.controlType) {
              ControlType.selectMulti => 'select',
              ControlType.rank => 'rank',
              _ => 'select1',
            };
            final isMultiple = type != 'select1';
            _triggerWarning(
              '$type question <value>s [$value] '
              '${isMultiple ? 'cannot' : 'should not'} contain spaces, and '
              'are recommended not to contain apostrophes/quotation marks',
              vagueLocation(child),
            );
          }
        }
      }
    }
    if (textRef == null && labelInnerText == null) {
      throw XFormParseException('<item> without proper <label>', e);
    }
    if (value == null) {
      throw XFormParseException('<item> without proper <value>', e);
    }
    q.addSelectChoice(
      textRef != null
          ? SelectChoice.localized(textRef, value)
          : SelectChoice(null, labelInnerText, value, isLocalizable: false),
    );
    _warnUnusedAttributes(e, const []);
  }

  void _parseItemset(QuestionDef q, KElement e) {
    final itemset = ItemsetBinding();
    var nodeset = e.attribute('', 'nodeset');
    if (nodeset == null) {
      throw XFormParseException(
        'No nodeset attribute in element: [${e.name}]. This is required. '
        '(Element Printout:${elementToString(e)})',
      );
    }
    try {
      final expression = _parseXPath(nodeset);
      if (expression is XPathFuncExpr) {
        if (expression.id.name != 'randomize') {
          throw XPathUnsupportedException(
            'The only function that may be used in a nodeset expression is '
            'randomize().',
          );
        }
        itemset.randomize = true;
        if (expression.args.length == 2) {
          itemset.randomSeedExpr = expression.args[1];
        }
        nodeset = cleanNodesetDefinition(nodeset);
      }
    } on XPathSyntaxException {
      throw XPathUnsupportedException(
        'Unsupported nodeset expression: $nodeset',
      );
    }
    itemset
      ..nodesetExpr = XPathConditional(_pathExpr(nodeset))
      ..contextRef = q.bind
      ..copyMode = false;
    for (final child in e.childElements) {
      switch (child.name) {
        case 'label':
          _warnUnusedAttributes(child, const ['ref']);
          var labelXpath =
              child.attribute('', 'ref') ??
              (throw XFormParseException(
                "<label> in <itemset> requires 'ref'",
              ));
          var isItext = false;
          if (labelXpath.startsWith(_dynamicItextOpen) &&
              labelXpath.endsWith(_dynamicItextClose)) {
            labelXpath = labelXpath.substring(
              _dynamicItextOpen.length,
              labelXpath.lastIndexOf(_dynamicItextClose),
            );
            isItext = true;
          }
          itemset
            ..labelExpr = XPathConditional(_pathExpr(labelXpath))
            ..labelIsItext = isItext;
        case 'copy':
          _warnUnusedAttributes(child, const ['ref']);
          final copyXpath =
              child.attribute('', 'ref') ??
              (throw XFormParseException("<copy> in <itemset> requires 'ref'"));
          itemset
            ..copyExpr = XPathConditional(_pathExpr(copyXpath))
            ..copyMode = true;
        case 'value':
          _warnUnusedAttributes(child, const ['ref', 'form']);
          final valueXpath =
              child.attribute('', 'ref') ??
              (throw XFormParseException(
                "<value> in <itemset> requires 'ref'",
              ));
          itemset.valueExpr = XPathConditional(_pathExpr(valueXpath));
      }
    }
    if (itemset.labelExpr == null) {
      throw XFormParseException('<itemset> requires <label>');
    } else if (itemset.copyExpr == null && itemset.valueExpr == null) {
      throw XFormParseException('<itemset> requires <copy> or <value>');
    }
    if (itemset.copyExpr != null && itemset.valueExpr == null) {
      _triggerWarning(
        '<itemset>s with <copy> are STRONGLY recommended to have <value> as '
        'well; pre-selecting, default answers, and display of answers will '
        'not work properly otherwise',
        vagueLocation(e),
      );
    }
    _itemsets.add(itemset);
    q.dynamicChoices = itemset;
    _warnUnusedAttributes(e, const ['nodeset']);
  }

  void _parseGroup(FormElement parent, KElement e, {required bool isRepeat}) {
    final group = GroupDef(isRepeat: isRepeat)..id = _serialQuestionId++;
    const usedAtts = [
      'ref', 'nodeset', 'bind', 'appearance', 'count', 'noAddRemove', //
    ];
    final ref = e.attribute(null, 'ref');
    final nodeset = e.attribute(null, 'nodeset');
    final bind = e.attribute(null, 'bind');
    group.appearance = e.attribute(null, 'appearance');
    TreeReference dataRef;
    if (bind != null) {
      final binding =
          _bindingsById[bind] ??
          (throw XFormParseException(
            'XForm Parse: invalid binding ID [$bind]',
            e,
          ));
      dataRef = binding.reference;
    } else {
      TreeReference? relative;
      if (isRepeat) {
        relative = _reference(
          nodeset ??
              (throw XFormParseException(
                "XForm Parse: <repeat> with no binding ('bind' or 'nodeset')",
                e,
              )),
        );
      } else if (ref != null) {
        relative = _reference(ref);
      } else if (nodeset != null) {
        relative = _reference(nodeset);
      }
      dataRef = _absoluteRef(relative, parent);
    }
    group.bind = dataRef;
    if (isRepeat) {
      _repeats.add(dataRef);
      final countRef = e.attribute(namespaceJavaRosa, 'count');
      if (countRef != null) {
        group
          ..count = _absoluteRef(_reference(countRef), parent)
          ..noAddRemove = true;
      } else {
        group.noAddRemove =
            e.attribute(namespaceJavaRosa, 'noAddRemove') != null;
      }
    }
    for (final child in e.childElements) {
      if (isRepeat && child.namespace == namespaceJavaRosa) {
        switch (child.name) {
          case 'chooseCaption':
            group.chooseCaption = _label(child);
          case 'addCaption':
            group.addCaption = _label(child);
          case 'delCaption':
            group.delCaption = _label(child);
          case 'doneCaption':
            group.doneCaption = _label(child);
          case 'addEmptyCaption':
            group.addEmptyCaption = _label(child);
          case 'doneEmptyCaption':
            group.doneEmptyCaption = _label(child);
          case 'entryHeader':
            group.entryHeader = _label(child);
          case 'delHeader':
            group.delHeader = _label(child);
          case 'mainHeader':
            group.mainHeader = _label(child);
        }
      }
      final actionHandler = _actionHandlers[child.name];
      if (isRepeat && actionHandler != null) {
        actionHandler(this, child, group);
      } else {
        _parseElement(child, group, topLevel: false);
      }
    }
    for (final a in e.attributes) {
      if (!usedAtts.contains(a.name)) {
        group.setAdditionalAttribute(a.namespace, a.name, a.value);
      }
    }
    _warnUnusedAttributes(e, usedAtts);
    parent.addChild(group);
  }

  TreeReference _formElementRef(FormElement element) => element is FormDef
      ? const TreeReference.root().extend(_mainInstanceNodeOrThrow().name, 0)
      : element.bind!;

  /// The main instance's data node; a parse error when there is none yet.
  ///
  /// JavaRosa crashes with a `NullPointerException` here (no `<model>`,
  /// no `<instance>`, or the body before the model); see
  /// conformance/DEVIATIONS.md.
  KElement _mainInstanceNodeOrThrow() =>
      _mainInstanceNode ?? (throw XFormParseException(_noMainInstance));

  static const _noMainInstance =
      'XForm Parse: the form has no main instance (an <instance> in the '
      '<model> of <h:head>, which must come before <h:body>)';

  /// [ref] (or the parent itself when `null`) anchored to [parent]'s
  /// reference. Port of `XFormParser.getAbsRef`.
  TreeReference _absoluteRef(TreeReference? ref, FormElement parent) =>
      FormDef.getAbsRef(ref, _formElementRef(parent));

  /// Replaces a non-repeat group wrapping exactly one repeat by the repeat
  /// (which takes the group's label). Port of `collapseRepeatGroups`.
  static void _collapseRepeatGroups(FormElement element) {
    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      if (child is! GroupDef) continue;
      var group = child;
      if (!group.isRepeat && group.children.length == 1) {
        final grandchild = group.children.first;
        if (grandchild is GroupDef && grandchild.isRepeat) {
          grandchild
            ..labelInnerText = group.labelInnerText
            ..textId = group.textId;
          if (element is FormDef) {
            element.replaceChildAt(i, grandchild);
          } else if (element is GroupDef) {
            element.replaceChildAt(i, grandchild);
          }
          group = grandchild;
        }
      }
      _collapseRepeatGroups(group);
    }
  }

  void _parseIText(KElement itext) {
    final localizer = Localizer(
      fallbackDefaultLocale: true,
      fallbackDefaultForm: true,
    );
    for (final translation in itext.childElements) {
      if (translation.name == 'translation') {
        _parseTranslation(localizer, translation);
      }
    }
    if (localizer.availableLocales.isEmpty) {
      throw XFormParseException('no <translation>s defined', itext);
    }
    localizer.defaultLocale ??= localizer.availableLocales.first;
    _warnUnusedAttributes(itext, const []);
    _localizer = localizer;
  }

  void _parseTranslation(Localizer localizer, KElement translation) {
    final lang = translation.attribute('', 'lang');
    if (lang == null || lang.isEmpty) {
      throw XFormParseException(
        'no language specified for <translation>',
        translation,
      );
    }
    final isDefault = translation.attribute('', 'default');
    if (!localizer.addAvailableLocale(lang)) {
      throw XFormParseException(
        "duplicate <translation> for language '$lang'",
        translation,
      );
    }
    if (isDefault != null) {
      if (localizer.defaultLocale != null) {
        throw XFormParseException(
          'more than one <translation> set as default',
          translation,
        );
      }
      localizer.defaultLocale = lang;
    }
    final source = TableLocaleSource();
    for (final text in translation.childElements) {
      if (text.name == 'text') _parseTextHandle(source, text);
    }
    _warnUnusedAttributes(translation, const ['lang', 'default']);
    localizer.registerLocaleResource(lang, source);
  }

  void _parseTextHandle(TableLocaleSource source, KElement text) {
    final id = text.attribute('', 'id');
    if (id == null || id.isEmpty) {
      throw XFormParseException('no id defined for <text>', text);
    }
    for (final value in text.childElements) {
      if (value.name != 'value') {
        throw XFormParseException(
          'Unrecognized element [${value.name}] in Itext->translation->text',
        );
      }
      var form = value.attribute('', 'form');
      if (form != null && form.isEmpty) form = null;
      final data = _label(value) ?? '';
      final textId = form == null ? id : '$id;$form';
      if (source.hasMapping(textId)) {
        throw XFormParseException(
          'duplicate definition for text ID "$id" and form "$form". Can only '
          'have one definition for each text form.',
          text,
        );
      }
      source.setLocaleMapping(textId, data);
      _warnUnusedAttributes(value, const ['form', 'id']);
    }
    _warnUnusedAttributes(text, const ['id', 'form']);
  }

  bool _hasITextMapping(String textId, String locale) =>
      _localizer!.hasMapping(locale, textId);

  void _verifyTextMappings(
    String textId,
    String type, {
    required bool allowSubforms,
  }) {
    // JavaRosa crashes with a NullPointerException without <itext>; see
    // conformance/DEVIATIONS.md.
    final localizer =
        _localizer ??
        (throw XFormParseException(
          "$type '$textId': the form has no <itext> translations",
        ));
    for (final locale in localizer.availableLocales) {
      if (_hasITextMapping(textId, locale) ||
          (allowSubforms && _hasSpecialFormMapping(textId, locale))) {
        continue;
      }
      if (locale == localizer.defaultLocale) {
        throw XFormParseException(
          "$type '$textId': text is not localizable for default locale "
          '[${localizer.defaultLocale}]!',
        );
      }
      _triggerWarning(
        "$type '$textId': text is not localizable for locale $locale.",
        null,
      );
    }
  }

  bool _hasSpecialFormMapping(String textId, String locale) {
    for (final guess in _itextKnownForms) {
      if (_hasITextMapping('$textId;$guess', locale)) return true;
    }
    for (final key in _localizer!.getLocaleData(locale)!.keys) {
      if (key.startsWith('$textId;')) {
        final form = key.substring(key.indexOf(';') + 1);
        if (!_itextKnownForms.contains(form)) _itextKnownForms.add(form);
        return true;
      }
    }
    return false;
  }

  static const _bindUsedAtts = [
    'id', 'nodeset', 'type', 'relevant', 'required', 'readonly', //
    'constraint', 'constraintMsg', 'calculate', 'preload', 'preloadParams',
    'requiredMsg', 'saveIncomplete',
  ];
  static const _bindPassedThroughAtts = ['requiredMsg', 'saveIncomplete'];

  void _parseBind(KElement element) {
    final binding = createBinding(
      element,
      form: _f,
      usedAttributes: _bindUsedAtts,
      passedThroughAttributes: _bindPassedThroughAtts,
      processors: _bindAttributeProcessors,
      absoluteRef: (ref) => _absoluteRef(ref, _f),
      parseReference: _reference,
      parseConditional: _conditional,
    );
    _warnUnusedAttributes(element, _bindUsedAtts);
    _bindings.add(binding);
    final id = binding.id;
    if (id != null) {
      if (_bindingsById.containsKey(id)) {
        throw XFormParseException(
          "XForm Parse: <bind>s with duplicate ID: '$id'",
        );
      }
      _bindingsById[id] = binding;
    }
  }

  // ------------------------------------------------------------ XPath

  /// Parses [xpath] like `XPathParseTool.parseXPath` during a JavaRosa
  /// parse: records `instance('id')` calls (only referenced secondary
  /// instances are loaded) and runs the XPath processors.
  XPathExpression _parseXPath(String xpath) {
    final expression = parseXPath(xpath);
    _recordInstanceCalls(expression);
    for (final processor in _xpathProcessors) {
      processor.processXPath(expression);
    }
    return expression;
  }

  void _recordInstanceCalls(XPathExpression x) {
    switch (x) {
      case XPathFuncExpr(:final id, :final args):
        if (id.name == 'instance' && args[0] is XPathStringLiteral) {
          _referencedInstanceIds.add((args[0] as XPathStringLiteral).value);
        }
        args.forEach(_recordInstanceCalls);
      case XPathBinaryOpExpr(:final a, :final b):
        _recordInstanceCalls(a);
        _recordInstanceCalls(b);
      case XPathNumNegExpr(:final a):
        _recordInstanceCalls(a);
      case XPathFilterExpr(:final x, :final predicates):
        _recordInstanceCalls(x);
        predicates.forEach(_recordInstanceCalls);
      case XPathPathExpr(:final filterExpr, :final steps):
        if (filterExpr != null) _recordInstanceCalls(filterExpr);
        for (final step in steps) {
          step.predicates.forEach(_recordInstanceCalls);
        }
      default:
        break;
    }
  }

  XPathConditional _conditional(String xpath) =>
      XPathConditional.fromParsed(_parseXPath(xpath), xpath);

  /// Port of `XPathReference.getPathExpr` (recording as [_parseXPath]).
  XPathPathExpr _pathExpr(String nodeset) {
    final XPathExpression expression;
    try {
      expression = _parseXPath(nodeset);
    } on XPathSyntaxException catch (e) {
      final message = e.message;
      throw XPathException(
        'Parse error in XPath path: [$nodeset].'
        '${message == null ? '' : '\n$message'}',
      );
    }
    if (expression is! XPathPathExpr) {
      throw XPathTypeMismatchException(
        'Expected XPath path, got XPath expression: [$nodeset],null',
      );
    }
    return expression;
  }

  TreeReference _reference(String nodeset) =>
      _pathExpr(nodeset).toTreeReference();

  // ------------------------------------------------------------ messages

  void _warnUnusedAttributes(KElement e, List<String> usedAtts) {
    final unused = [for (final a in e.attributes) a.name];
    for (final used in usedAtts) {
      unused.remove(used);
    }
    if (unused.isEmpty) return;
    _triggerWarning(
      'Warning: ${unused.length} Unrecognized attributes found in Element '
      '[${e.name}] and will be ignored: [${unused.join(',')}] ',
      vagueLocation(e),
    );
  }

  void _triggerWarning(String message, String? location) {
    final warning = 'XForm Parse Warning: $message${location ?? ''}';
    _log.warning(warning);
    _f.addParseWarning(warning);
    for (final callback in _warningCallbacks) {
      callback(warning);
    }
  }

  void _triggerError(String message) {
    final error = 'XForm Parse Error: $message';
    _log.severe(error);
    _f.addParseError(error);
    for (final callback in _errorCallbacks) {
      callback(error);
    }
  }
}
