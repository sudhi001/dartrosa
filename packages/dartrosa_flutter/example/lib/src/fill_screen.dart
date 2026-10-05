// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:dartrosa_collect/dartrosa_collect.dart';
import 'package:dartrosa_encryption/dartrosa_encryption.dart';
import 'package:dartrosa_flutter/dartrosa_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///
/// Leaving with answers not saved asks first (save a draft, discard or
/// stay). With a keyboard, Ctrl+S (Cmd+S on macOS) saves a draft.
class FillScreen extends StatefulWidget {
  /// Creates the screen.
  const FillScreen({
    required this.workspace,
    required this.instance,
    this.onClose,
    super.key,
  });

  /// Storage and form services.
  final Workspace workspace;

  /// The instance being filled.
  final SavedInstance instance;

  /// Closes the screen when it is shown beside the forms list; it pops
  /// its route otherwise.
  final VoidCallback? onClose;

  @override
  State<FillScreen> createState() => FillScreenState();
}

/// The state of a [FillScreen].
class FillScreenState extends State<FillScreen> {
  late final Future<Filling> _filling = _open();
  Filling? _opened;
  var _mode = XFormMode.pager;
  var _closed = false;

  /// Shows the form; a new key per mode starts the view afresh.
  var _form = GlobalKey<XFormViewState>();

  /// Whether answers changed since the last save.
  var _dirty = false;
  StreamSubscription<FormChange>? _changes;

  SavedInstance get _instance => widget.instance;

  Future<Filling> _open() async {
    final filling = await widget.workspace.startFilling(_instance);
    _opened = filling;
    _changes = filling.session.changes.listen((change) {
      if (change.kind == 'answer' || change.kind == 'repeat') _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _start(filling));
    return filling;
  }

  Future<void> _start(Filling filling) async {
    final audit = filling.audit;
    while (mounted && audit.requiresIdentity) {
      final identity = await _ask('Enter your name', 'Identity');
      if (identity == null) {
        if (mounted) _leave();
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
    builder: (context) => _TextPromptDialog(title: title, label: label),
  );

  /// Flushes the audit before a save; `false` if a change reason was
  /// needed and not given.
  Future<bool> _beforeSave(FormAudit audit) async {
    audit.beforeSave();
    if (!audit.requiresChangeReason) return true;
    final reason = await _ask('Why are you changing this form?', 'Reason');
    return audit.changeReasonGiven(reason);
  }

  Future<void> _saveDraft(Filling filling) async {
    if (!await _beforeSave(filling.audit)) return;
    await widget.workspace.saveDraft(_instance, filling.session);
    filling.audit.saved(exiting: false, finalized: false);
    _dirty = false;
    if (mounted) _snack('Draft saved');
  }

  /// Leaves the form: closes the pane beside the list, or pops.
  void _leave() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Whether the form may be left: true when nothing changed since the
  /// last save, else asks to save a draft, discard the changes or stay.
  Future<bool> confirmLeave() async {
    final filling = _opened;
    if (!_dirty || _closed || filling == null) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this form?'),
        content: const Text(
          'Your answers since the last save will be lost unless you save '
          'a draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    switch (choice) {
      case 'save':
        await _saveDraft(filling);
        return !_dirty;
      case 'discard':
        _dirty = false;
        return true;
      default:
        return false;
    }
  }

  Future<void> _tryLeave() async {
    if (await confirmLeave() && mounted) _leave();
  }

  Future<void> _finalized(Filling filling, Submission submission) async {
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
    _dirty = false;
    await _close();
    if (!mounted) return;
    _snack(
      entry.encrypted
          ? 'Finalized and encrypted: see the outbox'
          : 'Finalized: see the outbox',
    );
    _leave();
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
    unawaited(_changes?.cancel());
    if (!_closed) {
      _opened?.audit.exitedWithoutSaving();
      unawaited(_close());
    }
    unawaited(_opened?.session.close());
    super.dispose();
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(Filling? filling) => {
    if (filling != null)
      for (final meta in [false, true])
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !meta,
          meta: meta,
        ): () =>
            _saveDraft(filling),
  };

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _filling,
    builder: (context, snapshot) {
      final filling = snapshot.data;
      final session = filling?.session;
      final scaffold = Scaffold(
        appBar: AppBar(
          // Beside the list: a close button instead of back.
          leading: widget.onClose == null
              ? null
              : CloseButton(onPressed: _tryLeave),
          title: Text(
            session?.definition.title ?? _instance.form.displayTitle,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (filling != null)
              IconButton(
                tooltip: 'Form outline',
                icon: const Icon(Icons.toc),
                onPressed: () => _form.currentState?.showOutline(),
              ),
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
              onPressed: () => setState(() {
                _mode = _mode == XFormMode.pager
                    ? XFormMode.scroll
                    : XFormMode.pager;
                _form = GlobalKey();
              }),
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
            key: _form,
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
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_tryLeave());
        },
        child: CallbackShortcuts(
          bindings: _shortcuts(filling),
          child: scaffold,
        ),
      );
    },
  );
}

/// Asks for a line of text; pops it, or `null` when cancelled.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('OK'),
      ),
    ],
  );
}
