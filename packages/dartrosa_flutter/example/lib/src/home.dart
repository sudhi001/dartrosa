// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'corpus.dart';
import 'fill_screen.dart';
import 'workspace.dart';

/// Opens an instance for filling.
typedef OpenInstance = void Function(SavedInstance instance);

/// The app's destinations.
const _destinations = [
  (
    icon: Icons.description_outlined,
    selected: Icons.description,
    label: 'Forms',
  ),
  (
    icon: Icons.edit_note_outlined,
    selected: Icons.edit_note,
    label: 'Instances',
  ),
  (icon: Icons.outbox_outlined, selected: Icons.outbox, label: 'Outbox'),
];

const _titles = ['DartRosa forms', 'Instances', 'Outbox'];

/// Forms, saved instances and the outbox, laid out for the window:
///
/// * narrower than 600dp: a navigation bar; a form opens full screen;
/// * 600dp to 839dp: a navigation rail; a form opens full screen;
/// * 840dp and wider: a navigation rail (extended from 1600dp) and the
///   forms or instances list beside the form being filled.
///
/// With a keyboard, Ctrl+F (Cmd+F on macOS) searches the forms and
/// Ctrl+1/2/3 switch destinations.
class HomeScreen extends StatefulWidget {
  /// Creates the screen.
  const HomeScreen({required this.workspace, super.key});

  /// Storage and form services.
  final Workspace workspace;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _tab = 0;

  /// The instance filled beside the list on wide windows.
  SavedInstance? _selected;
  GlobalKey<FillScreenState> _detailKey = GlobalKey();
  final _search = FocusNode(debugLabel: 'form search');
  final _focus = FocusNode(debugLabel: 'home', skipTraversal: true);

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Fills [instance]: beside the list on wide windows, else full screen.
  Future<void> _open(SavedInstance instance, {required bool wide}) async {
    if (!wide) return fill(context, widget.workspace, instance);
    // Leaving the form being filled may need confirmation.
    if (!(await _detailKey.currentState?.confirmLeave() ?? true)) return;
    if (!mounted) return;
    setState(() {
      _selected = instance;
      _detailKey = GlobalKey();
    });
  }

  void _closeDetail() => setState(() => _selected = null);

  void _select(int tab) => setState(() => _tab = tab);

  /// Shows the forms and focuses their search field (Ctrl+F).
  void _searchForms() {
    _select(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search.requestFocus();
    });
  }

  Widget _page(bool wide) {
    void open(SavedInstance instance) => _open(instance, wide: wide);
    return ListenableBuilder(
      listenable: widget.workspace,
      builder: (context, _) => switch (_tab) {
        0 => FormsPage(
          workspace: widget.workspace,
          onOpen: open,
          searchFocus: _search,
          selected: wide ? _selected?.form : null,
        ),
        1 => InstancesPage(workspace: widget.workspace, onOpen: open),
        _ => OutboxPage(workspace: widget.workspace),
      },
    );
  }

  Widget _detail() => FillScreen(
    key: _detailKey,
    workspace: widget.workspace,
    instance: _selected!,
    onClose: _closeDetail,
  );

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    for (final meta in [false, true]) ...{
      SingleActivator(LogicalKeyboardKey.keyF, control: !meta, meta: meta):
          _searchForms,
      SingleActivator(
        LogicalKeyboardKey.digit1,
        control: !meta,
        meta: meta,
      ): () =>
          _select(0),
      SingleActivator(
        LogicalKeyboardKey.digit2,
        control: !meta,
        meta: meta,
      ): () =>
          _select(1),
      SingleActivator(
        LogicalKeyboardKey.digit3,
        control: !meta,
        meta: meta,
      ): () =>
          _select(2),
    },
  };

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: _shortcuts,
    child: Focus(
      focusNode: _focus,
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) => _layout(constraints.maxWidth),
      ),
    ),
  );

  Widget _layout(double width) {
    final wide = width >= 840;
    // A form opened beside the list stays open (same state) when the
    // window gets narrower: it fills the window until closed.
    if (!wide && _selected != null) return _detail();
    if (width < 600) {
      return Scaffold(
        appBar: AppBar(title: Text(_titles[_tab])),
        body: _page(false),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      );
    }
    final rail = NavigationRail(
      selectedIndex: _tab,
      onDestinationSelected: _select,
      extended: width >= 1600,
      labelType: width >= 1600
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selected),
            label: Text(d.label),
          ),
      ],
    );
    final Widget content;
    if (!wide) {
      content = Scaffold(
        appBar: AppBar(title: Text(_titles[_tab])),
        body: _page(false),
      );
    } else if (_tab == 2) {
      content = Scaffold(
        appBar: AppBar(title: Text(_titles[_tab])),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: _page(true),
          ),
        ),
      );
    } else {
      // List and detail side by side.
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: width >= 1600 ? 420 : 360,
            child: Scaffold(
              appBar: AppBar(title: Text(_titles[_tab])),
              body: _page(true),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _selected == null ? const _NoSelection() : _detail()),
        ],
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            rail,
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// The detail pane before a form is chosen.
class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Choose a form to fill',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'It opens here, next to the list.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [instance] in a [FillScreen].
Future<void> fill(
  BuildContext context,
  Workspace workspace,
  SavedInstance instance,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => FillScreen(workspace: workspace, instance: instance),
  ),
);

/// The bundled forms, filtered by a search field.
class FormsPage extends StatefulWidget {
  /// Creates the page.
  const FormsPage({
    required this.workspace,
    this.onOpen,
    this.searchFocus,
    this.selected,
    super.key,
  });

  /// Storage and form services.
  final Workspace workspace;

  /// Opens a new instance; by default in a [FillScreen] route.
  final OpenInstance? onOpen;

  /// The search field's focus node.
  final FocusNode? searchFocus;

  /// The form filled beside the list, highlighted.
  final CorpusForm? selected;

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final forms = [
      for (final form in widget.workspace.corpus.forms)
        if (form.path.toLowerCase().contains(query) ||
            form.displayTitle.toLowerCase().contains(query))
          form,
    ];
    final open =
        widget.onOpen ??
        (instance) => fill(context, widget.workspace, instance);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            focusNode: widget.searchFocus,
            hintText: 'Search ${widget.workspace.corpus.forms.length} forms',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        Expanded(
          child: forms.isEmpty
              ? Center(child: Text('No form matches "$_query".'))
              : ListView.builder(
                  itemCount: forms.length,
                  itemBuilder: (context, i) => _FormTile(
                    widget.workspace,
                    forms[i],
                    open: open,
                    selected: identical(forms[i], widget.selected),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile(
    this.workspace,
    this.form, {
    required this.open,
    required this.selected,
  });

  final Workspace workspace;
  final CorpusForm form;
  final OpenInstance open;
  final bool selected;

  @override
  Widget build(BuildContext context) => ListTile(
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
    title: Text(form.displayTitle),
    subtitle: Text(form.path),
    trailing: form.javarosaParses
        ? null
        : const Tooltip(
            message: 'JavaRosa rejects this form too',
            child: Icon(Icons.block),
          ),
    onTap: () => open(workspace.newInstance(form)),
  );
}

/// Drafts (resume) and finalized instances (edit, view, audit).
class InstancesPage extends StatelessWidget {
  /// Creates the page.
  const InstancesPage({required this.workspace, this.onOpen, super.key});

  /// Storage and form services.
  final Workspace workspace;

  /// Opens an instance; by default in a [FillScreen] route.
  final OpenInstance? onOpen;

  @override
  Widget build(BuildContext context) {
    final instances = workspace.instances;
    if (instances.isEmpty) {
      return const _Empty(
        icon: Icons.edit_note,
        text: 'Saved and finalized forms show here.',
      );
    }
    return ListView.builder(
      itemCount: instances.length,
      itemBuilder: (context, i) => _InstanceTile(
        workspace: workspace,
        instance: instances[i],
        open: onOpen ?? (instance) => fill(context, workspace, instance),
      ),
    );
  }
}

/// A saved instance: tap to resume a draft or view a finalized one; its
/// menu edits, shows the XML or the audit log.
class _InstanceTile extends StatelessWidget {
  const _InstanceTile({
    required this.workspace,
    required this.instance,
    required this.open,
  });

  final Workspace workspace;
  final SavedInstance instance;
  final OpenInstance open;

  @override
  Widget build(BuildContext context) {
    final status = [
      if (instance.finalized) 'Finalized' else 'Draft',
      if (instance.editOf case final original?)
        'edit ${instance.editNumber} of #${original.id}',
      TimeOfDay.fromDateTime(instance.saved).format(context),
    ].join(' · ');
    return ListTile(
      leading: Icon(instance.finalized ? Icons.task_alt : Icons.edit_note),
      title: Text('#${instance.id} ${instance.form.displayTitle}'),
      subtitle: Text(status),
      onTap: instance.finalized
          ? () => showText(context, 'Instance #${instance.id}', instance.xml)
          : () => open(instance),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (action) => switch (action) {
          'edit' => open(
            workspace.newInstance(instance.form, editOf: instance),
          ),
          'audit' => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AuditScreen(instance: instance),
            ),
          ),
          _ => showText(context, 'Instance #${instance.id}', instance.xml),
        },
        itemBuilder: (context) => [
          if (instance.finalized && instance.instanceId != null)
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'xml', child: Text('View XML')),
          const PopupMenuItem(value: 'audit', child: Text('Audit log')),
        ],
      ),
    );
  }
}

/// Exported submissions and their files.
class OutboxPage extends StatelessWidget {
  /// Creates the page.
  const OutboxPage({required this.workspace, super.key});

  /// Storage and form services.
  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final outbox = workspace.outbox;
    if (outbox.isEmpty) {
      return const _Empty(
        icon: Icons.outbox_outlined,
        text: 'Finalized forms are exported here.',
      );
    }
    return ListView.builder(
      itemCount: outbox.length,
      // Keyed: new entries go first, expansion follows its entry.
      itemBuilder: (context, i) =>
          _OutboxTile(outbox[i], key: ObjectKey(outbox[i])),
    );
  }
}

/// An exported submission, expanding to its files.
class _OutboxTile extends StatelessWidget {
  const _OutboxTile(this.entry, {super.key});

  final OutboxEntry entry;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: Icon(entry.encrypted ? Icons.lock_outline : Icons.upload_file),
    title: Text('#${entry.instance.id} ${entry.instance.form.displayTitle}'),
    subtitle: Text(
      [
        if (entry.encrypted) 'Encrypted',
        '${entry.files.length} file(s)',
        if (entry.entities > 0) '${entry.entities} entit(ies)',
      ].join(' · '),
    ),
    children: [
      for (final MapEntry(key: name, value: bytes) in entry.files.entries)
        ListTile(
          dense: true,
          title: Text(name),
          subtitle: Text('${bytes.length} bytes'),
          onTap: () => showText(
            context,
            name,
            name.endsWith('.enc')
                ? base64.encode(bytes)
                : utf8.decode(bytes, allowMalformed: true),
          ),
        ),
    ],
  );
}

/// An empty list: an icon and what will show there.
class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Shows [text] in a dialog that can copy it.
Future<void> showText(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

/// An instance's audit log (`audit.csv`) as a table.
class AuditScreen extends StatelessWidget {
  /// Creates the screen.
  const AuditScreen({required this.instance, super.key});

  /// The instance audited.
  final SavedInstance instance;

  @override
  Widget build(BuildContext context) {
    final lines = (instance.audit.contents ?? '').trim().split('\n');
    final rows = [
      for (final line in lines)
        if (line.isNotEmpty) csvFields(line),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('Audit #${instance.id}')),
      body: rows.isEmpty
          ? const Center(child: Text('This form has no audit (meta/audit).'))
          : SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (final column in rows.first)
                      DataColumn(label: Text(column)),
                  ],
                  rows: [
                    for (final row in rows.skip(1))
                      DataRow(
                        cells: [
                          for (var i = 0; i < rows.first.length; i++)
                            DataCell(Text(i < row.length ? row[i] : '')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The fields of the CSV [line] (quoted fields may hold commas and `""`).
List<String> csvFields(String line) => [
  for (final m in RegExp(r'(?:^|,)("(?:[^"]|"")*"|[^,]*)').allMatches(line))
    switch (m.group(1)!) {
      final f when f.startsWith('"') =>
        f.substring(1, f.length - 1).replaceAll('""', '"'),
      final f => f,
    },
];
