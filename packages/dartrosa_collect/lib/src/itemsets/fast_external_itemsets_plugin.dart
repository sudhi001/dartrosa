import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartrosa/dartrosa.dart';
import 'package:dartrosa/javarosa.dart';

import 'fast_external_itemsets_repository.dart';
import 'itemset_dao.dart';
import 'itemsets_csv_reader.dart';

/// Imports a form's `itemsets.csv` when it is loaded, so selects with a
/// `query` attribute can read their choices with [loadItemsetChoices].
///
/// ```dart
/// final config = DartRosaConfig(
///   resolver: mediaResolver, // serves jr://file/itemsets.csv
///   plugins: [FastExternalItemsetsPlugin()],
/// );
/// ```
///
/// Ports what Collect's `FormLoaderTask` does after parsing a form
/// (`processItemSets` and `readCSV`): the CSV is imported only when its
/// MD5 differs from the stored import's.
final class FastExternalItemsetsPlugin extends FormLoadPlugin {
  /// Creates the plugin.
  ///
  /// [repository] gives the store for a form's import (default: a fresh
  /// in-memory one per form, so the CSV is imported on every load). With a
  /// shared persistent repository, [csvPath] must give each form's CSV a
  /// distinct key (Collect uses the file's absolute path); by default it is
  /// [mediaUri]. [onWarning] receives import errors (Collect shows them
  /// when the form opens).
  FastExternalItemsetsPlugin({
    FastExternalItemsetsRepository Function(FormDef form)? repository,
    String Function(FormDef form)? csvPath,
    this.mediaUri = FastExternalItemsetsDefaults.mediaUri,
    this.onWarning,
  }) : _repository = repository ?? _inMemory,
       _csvPath = csvPath;

  static FastExternalItemsetsRepository _inMemory(FormDef form) =>
      InMemoryFastExternalItemsetsRepository();

  final FastExternalItemsetsRepository Function(FormDef form) _repository;
  final String Function(FormDef form)? _csvPath;

  /// The URI of the form's `itemsets.csv`, read through the config's
  /// resolver.
  final String mediaUri;

  /// Receives import errors.
  final void Function(String message)? onWarning;

  @override
  Future<void> prepareForm(FormDef form, ResourceResolver resolver) async {
    final path = _csvPath?.call(form) ?? mediaUri;
    final repository = _repository(form);
    List<int> bytes;
    try {
      bytes = await resolver.read(mediaUri);
    } on ResourceNotFoundException {
      form.extras.put(
        FastExternalItemsets(path, fileExists: false, table: null),
      );
      return;
    }
    final table = await importItemsets(
      repository,
      path,
      bytes,
      onWarning: onWarning,
    );
    form.extras.put(FastExternalItemsets(path, fileExists: true, table: table));
  }
}

/// Imports [bytes], the `itemsets.csv` keyed [path], into [repository]
/// unless the stored import has the same MD5; returns the table (`null`
/// when the import failed before creating it).
///
/// Port of `FormLoaderTask.processItemSets` and `readCSV`: the first
/// record is the header (empty column names are skipped); each further
/// record is a row. Like Collect, a read error keeps the rows read so far
/// and is reported to [onWarning]; duplicate column names (an SQL error
/// in Collect) leave no table. A row with more values than the header
/// throws [StateError] (Collect crashes).
Future<ItemsetTable?> importItemsets(
  FastExternalItemsetsRepository repository,
  String path,
  List<int> bytes, {
  void Function(String message)? onWarning,
}) async {
  final csvMd5 = md5.convert(bytes).toString();
  final oldMd5 = await repository.getHash(path);
  if (oldMd5 == csvMd5) return repository.getTable(path);
  // the csv has been updated (or is new): delete the old entries and read
  // the new
  if (oldMd5 != null) await repository.deleteAllByCsvPath(path);

  final reader = ItemsetsCsvReader(utf8.decode(bytes, allowMalformed: true));
  List<String>? columnHeaders;
  List<int>? columnPositions;
  final rows = <List<String?>>[];
  try {
    List<String>? nextLine;
    while ((nextLine = reader.readNext()) != null) {
      final line = nextLine!;
      if (columnHeaders == null) {
        // first line of csv is column headers
        final positions = [
          for (var i = 0; i < line.length; i++)
            if (line[i].isNotEmpty) i,
        ];
        final names = [for (final i in positions) line[i]];
        final lower = {for (final name in names) name.toLowerCase()};
        if (lower.length != names.length) {
          throw ItemsetsCsvException(
            'duplicate column name in itemsets.csv header: $line',
          );
        }
        columnHeaders = line;
        columnPositions = positions;
        continue;
      }
      // rows don't necessarily use all the columns but a column is
      // guaranteed to exist for a row (or else blow up)
      if (line.length > columnHeaders.length) {
        throw StateError(
          'itemsets.csv row has more values than the header: $line',
        );
      }
      rows.add([
        for (final i in columnPositions!) i < line.length ? line[i] : null,
      ]);
    }
  } on ItemsetsCsvException catch (e) {
    onWarning?.call(e.message);
  }
  if (columnHeaders == null) return null;
  final table = ItemsetTable([
    for (final i in columnPositions!) columnHeaders[i],
  ], rows);
  await repository.save(path, csvMd5, table);
  return table;
}

/// The choices to show for [prompt]: those of `itemsets.csv` when it has
/// a `query` attribute, else its own.
///
/// Port of the fast external itemset part of Collect's
/// `SelectChoiceUtils.loadSelectChoices` (the `search()` part is in
/// `dartrosa_external_data`). Throws [ItemsetsFileNotFoundException] and
/// [XPathSyntaxException] like [ItemsetDao.getItems].
List<SelectChoice> loadItemsetChoices(FormEntryPrompt prompt) {
  if (!isFastExternalItemsetUsed(prompt)) return prompt.selectChoices;
  return const ItemsetDao().getItems(prompt);
}

/// The label to show for the answer of [prompt], a text question with a
/// `query` attribute, in the form's current language (Collect shows it in
/// the hierarchy); `null` for other questions or without a match.
///
/// Port of the itemset branch of Collect's
/// `QuestionAnswerProcessor.getQuestionAnswer`.
String? itemsetAnswerLabel(FormEntryPrompt prompt) {
  final answer = prompt.answerValue;
  if (answer == null ||
      prompt.dataType != DataType.text ||
      !isFastExternalItemsetUsed(prompt)) {
    return null;
  }
  final form = prompt.form;
  final languages = form.localizer?.availableLocales ?? const [];
  final language = languages.isNotEmpty ? form.localizer!.locale : '';
  return const ItemsetDao().getItemLabel(answer.displayText, form, language);
}
