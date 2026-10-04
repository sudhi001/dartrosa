import '../form_api/form_entry_controller.dart';
import '../model/actions/actions.dart';
import '../model/condition/evaluation_context.dart';
import '../model/instance/external/external_instance_parser.dart';
import '../model/instance/tree_reference.dart';
import '../model/utils/question_preloader.dart';
import '../reference/resource_resolver.dart';

/// Everything that configures how forms are parsed and filled. Immutable;
/// create one per app (or per form source) and reuse it.
final class DartRosaConfig {
  /// Creates a configuration.
  const DartRosaConfig({
    this.resolver,
    this.functions = const [],
    this.filterStrategies = const [],
    this.parseProcessors = const [],
    this.finalizationProcessors = const [],
    this.preloadHandlers = const [],
    this.externalInstanceParser,
    this.setGeopointAction,
    this.properties,
  });

  /// Reads `jr://` resources (media, CSV/XML/GeoJSON instances, last-saved).
  final ResourceResolver? resolver;

  /// Custom XPath functions (JavaRosa's `addFunctionHandler`).
  final List<XPathFunctionHandler> functions;

  /// Predicate filter strategies tried before the built-in ones.
  final List<FilterStrategy> filterStrategies;

  /// Parser plugins: bind/model attribute, question, form, XPath and
  /// external-instance processors (JavaRosa's `XFormParser.addProcessor`).
  final List<Object> parseProcessors;

  /// Run when a form is finalized (JavaRosa's `addPostProcessor`).
  final List<FormEntryFinalizationProcessor> finalizationProcessors;

  /// Extra or replacement `jr:preload` handlers.
  final List<PreloadHandler> preloadHandlers;

  /// Secondary-instance parsing (custom formats, instance providers).
  final ExternalInstanceParser? externalInstanceParser;

  /// Builds the action for `odk:setgeopoint` (e.g. backed by the device's
  /// location); a stub that does nothing by default.
  final SetGeopointAction Function(TreeReference target)? setGeopointAction;

  /// Device and user properties (`deviceid`, `username`, `email`, ...).
  final PropertyManager? properties;
}
