import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'corpus.dart';
import 'fill_screen.dart';
import 'workspace.dart';

/// Forms, saved instances and the outbox.
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(const ['DartRosa forms', 'Instances', 'Outbox'][_tab]),
    ),
    body: ListenableBuilder(
      listenable: widget.workspace,
      builder: (context, _) => switch (_tab) {
        0 => FormsPage(workspace: widget.workspace),
        1 => InstancesPage(workspace: widget.workspace),
        _ => OutboxPage(workspace: widget.workspace),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (tab) => setState(() => _tab = tab),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.description_outlined),
          label: 'Forms',
        ),
        NavigationDestination(icon: Icon(Icons.edit_note), label: 'Instances'),
        NavigationDestination(
          icon: Icon(Icons.outbox_outlined),
          label: 'Outbox',
        ),
      ],
    ),
  );
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
  const FormsPage({required this.workspace, super.key});

  /// Storage and form services.
  final Workspace workspace;

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            hintText: 'Search ${widget.workspace.corpus.forms.length} forms',
            leading: const Icon(Icons.search),
            onChanged: (q) => setState(() => _query = q),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: forms.length,
            itemBuilder: (context, i) => _FormTile(widget.workspace, forms[i]),
          ),
        ),
      ],
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile(this.workspace, this.form);

  final Workspace workspace;
  final CorpusForm form;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(form.displayTitle),
    subtitle: Text(form.path),
    trailing: form.javarosaParses
        ? null
        : const Tooltip(
            message: 'JavaRosa rejects this form too',
            child: Icon(Icons.block),
          ),
    onTap: () => fill(context, workspace, workspace.newInstance(form)),
  );
}

/// Drafts (resume) and finalized instances (edit, view, audit).
class InstancesPage extends StatelessWidget {
  /// Creates the page.
  const InstancesPage({required this.workspace, super.key});

  /// Storage and form services.
  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final instances = workspace.instances;
    if (instances.isEmpty) {
      return const Center(child: Text('Saved and finalized forms show here.'));
    }
    return ListView.builder(
      itemCount: instances.length,
      itemBuilder: (context, i) {
        final instance = instances[i];
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
              ? () =>
                    showText(context, 'Instance #${instance.id}', instance.xml)
              : () => fill(context, workspace, instance),
          trailing: PopupMenuButton<String>(
            onSelected: (action) => switch (action) {
              'edit' => fill(
                context,
                workspace,
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
      },
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
      return const Center(child: Text('Finalized forms are exported here.'));
    }
    return ListView(
      children: [
        for (final entry in outbox)
          ExpansionTile(
            leading: Icon(
              entry.encrypted ? Icons.lock_outline : Icons.upload_file,
            ),
            title: Text(
              '#${entry.instance.id} ${entry.instance.form.displayTitle}',
            ),
            subtitle: Text(
              [
                if (entry.encrypted) 'Encrypted',
                '${entry.files.length} file(s)',
                if (entry.entities > 0) '${entry.entities} entit(ies)',
              ].join(' · '),
            ),
            children: [
              for (final MapEntry(key: name, value: bytes)
                  in entry.files.entries)
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
          ),
      ],
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
