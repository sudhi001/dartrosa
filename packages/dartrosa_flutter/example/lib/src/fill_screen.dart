import 'dart:async';

import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';

import 'corpus.dart';
import 'external_choices.dart';
import 'workspace.dart';

/// Shows a form's images from its asset folder.
class AssetDelegates extends XFormDelegates {
  /// Creates delegates for [resolver]'s folder, holding [files].
  const AssetDelegates(this.resolver, this.files);

  /// Maps `jr://` URIs to assets.
  final AssetResolver resolver;

  /// The files in the folder; images that are missing aren't shown.
  final List<String> files;

  @override
  ImageProvider? image(String uri) => switch (resolver.assetKey(uri)) {
    final key? when files.contains(key.substring(key.lastIndexOf('/') + 1)) =>
      AssetImage(key, bundle: resolver.bundle),
    _ => null,
  };
}

/// Fills [instance]: a new instance, a draft, or an edit.
class FillScreen extends StatefulWidget {
  /// Creates the screen.
  const FillScreen({
    required this.workspace,
    required this.instance,
    super.key,
  });

  /// Storage and form services.
  final Workspace workspace;

  /// The instance being filled.
  final SavedInstance instance;

  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _Filling {
  _Filling(this.session, this.audit);

  final FormSession session;
  final FormAudit audit;
  StreamSubscription<FormChange>? changes;

  Future<void> close() async {
    await changes?.cancel();
    await audit.close();
  }
}

class _FillScreenState extends State<FillScreen> {
  late final Future<_Filling> _filling = _open();
  _Filling? _opened;
  var _mode = XFormMode.pager;
  var _closed = false;

  SavedInstance get _instance => widget.instance;

  Future<_Filling> _open() async {
    final definition = await widget.workspace.load(_instance.form);
    final session = widget.workspace.open(definition, _instance);
    final filling = _Filling(
      session,
      FormAudit(
        session,
        store: _instance.audit,
        isEditing: _instance.editOf != null,
      ),
    );
    // The pager moves without telling the app: log a new screen when an
    // answer is given somewhere else.
    var position = session.navigator.position;
    filling.changes = session.changes.listen((_) {
      if (session.navigator.position != position) {
        position = session.navigator.position;
        filling.audit.screenChanged();
      }
    });
    _opened = filling;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start(filling));
    return filling;
  }

  Future<void> _start(_Filling filling) async {
    final audit = filling.audit;
    while (mounted && audit.requiresIdentity) {
      final identity = await _ask('Enter your name', 'Identity');
      if (identity == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      audit.identify(identity);
    }
    if (_instance.xml.isEmpty) {
      audit.formStarted();
    } else {
      audit.formResumed();
    }
  }

  Future<String?> _ask(String title, String label) => showDialog<String>(
    context: context,
    builder: (context) {
      final text = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  /// Flushes the audit before a save; `false` if a change reason was
  /// needed and not given.
  Future<bool> _beforeSave(FormAudit audit) async {
    audit.beforeSave();
    if (!audit.requiresChangeReason) return true;
    final reason = await _ask('Why are you changing this form?', 'Reason');
    return audit.changeReasonGiven(reason);
  }

  Future<void> _saveDraft(_Filling filling) async {
    if (!await _beforeSave(filling.audit)) return;
    await widget.workspace.saveDraft(_instance, filling.session);
    filling.audit.saved(exiting: false, finalized: false);
    if (mounted) _snack('Draft saved');
  }

  Future<void> _finalized(_Filling filling, Submission submission) async {
    if (!await _beforeSave(filling.audit)) return;
    final OutboxEntry entry;
    try {
      entry = await widget.workspace.finalize(
        _instance,
        filling.session,
        submission,
      );
    } on EncryptionException catch (e) {
      filling.audit.finalizeFailed();
      if (mounted) _snack('Could not encrypt: ${e.message}');
      return;
    }
    filling.audit.saved(exiting: true, finalized: true);
    await _close();
    if (!mounted) return;
    _snack(
      entry.encrypted
          ? 'Finalized and encrypted: see the outbox'
          : 'Finalized: see the outbox',
    );
    Navigator.of(context).pop();
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    final filling = _opened;
    if (filling == null) return;
    await filling.close();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    if (!_closed) {
      _opened?.audit.exitedWithoutSaving();
      unawaited(_close());
    }
    unawaited(_opened?.session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _filling,
    builder: (context, snapshot) {
      final filling = snapshot.data;
      final session = filling?.session;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            session?.definition.title ?? _instance.form.displayTitle,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (session != null && session.definition.languages.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Language',
                icon: const Icon(Icons.translate),
                initialValue: session.language,
                onSelected: (language) =>
                    setState(() => session.language = language),
                itemBuilder: (context) => [
                  for (final language in session.definition.languages)
                    PopupMenuItem(value: language, child: Text(language)),
                ],
              ),
            IconButton(
              tooltip: _mode == XFormMode.pager
                  ? 'One page'
                  : 'One question per screen',
              icon: Icon(
                _mode == XFormMode.pager
                    ? Icons.view_agenda_outlined
                    : Icons.view_carousel_outlined,
              ),
              onPressed: () => setState(
                () => _mode = _mode == XFormMode.pager
                    ? XFormMode.scroll
                    : XFormMode.pager,
              ),
            ),
            if (filling != null)
              IconButton(
                tooltip: 'Save draft',
                icon: const Icon(Icons.save_outlined),
                onPressed: () => _saveDraft(filling),
              ),
          ],
        ),
        body: switch (snapshot) {
          AsyncSnapshot(:final error?) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('This form could not be loaded:\n\n$error'),
            ),
          ),
          _ when filling == null => const Center(
            child: CircularProgressIndicator(),
          ),
          _ => XFormView(
            key: ValueKey(_mode),
            session: filling.session,
            mode: _mode,
            delegates: AssetDelegates(
              AssetResolver(widget.workspace.bundle, _instance.form.folder),
              widget.workspace.corpus.mediaOf(_instance.form),
            ),
            widgetOverrides: externalChoiceOverrides,
            onFinalized: (submission) => _finalized(filling, submission),
          ),
        },
      );
    },
  );
}
