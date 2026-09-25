import 'package:flutter/material.dart';
import 'package:klhu/content_naming.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:klhu/models/content.dart';
import 'package:klhu/services/content_store.dart';

/// The unified content list (spec 008, FR-004): every pre-set and every saved
/// page in one place, newest first.
///
/// Pushing this screen resolves to a [ContentListResult], or to null when the
/// user goes back — acting on it is the caller's decision, because only the
/// caller knows whether the page has unsaved edits.
///
/// What the list can resolve to (spec 008's push, widened by 011 US3): a picked
/// entry, or a request for a new content. The page decides what that request
/// means: nothing is created until Save, which 008 names from the text.
sealed class ContentListResult {
  const ContentListResult();
}

/// The user picked an existing entry.
class PickedContent extends ContentListResult {
  final SavedContent entry;

  const PickedContent(this.entry);
}

/// The user asked for a new content: a blank page, not an entry.
class NewContentRequest extends ContentListResult {
  const NewContentRequest();
}

class ContentListScreen extends StatefulWidget {
  final ContentStore store;

  const ContentListScreen({super.key, required this.store});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

/// One row's display state: the entry plus the name to show for it. Pre-set
/// names come from the catalog in the interface's language, so they follow the
/// language dropdown instead of freezing the name the index was seeded with.
class _Row {
  final SavedContent entry;
  final String name;

  _Row(this.entry, this.name);
}

class _ContentListScreenState extends State<ContentListScreen> {
  Future<List<_Row>>? _rows;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rows ??= _loadRows();
  }

  Future<List<_Row>> _loadRows() async {
    final entries = await widget.store.list();
    return [
      for (final entry in entries) _Row(entry, await _displayName(entry)),
    ];
  }

  /// A pre-set's title is regenerated from its catalog text, so the row always
  /// echoes its own content instead of a label baked into the index by an older
  /// build (spec 008; auto-generated names apply to pre-sets too).
  Future<String> _displayName(SavedContent entry) async {
    if (!entry.isPreset) return entry.name;
    final preset = await widget.store.presetFor(entry.id);
    return preset == null ? entry.name : contentNameFrom(preset.text);
  }

  void _reload() {
    // A block body: an arrow body would return the assigned Future and
    // setState() rejects a callback that returns one.
    setState(() {
      _rows = _loadRows();
    });
  }

  String _languageLabel(AppLocalizations l10n, String language) =>
      switch (language) {
        'zh-Hans' => l10n.chineseNative,
        'es' => l10n.spanishNative,
        _ => l10n.englishNative,
      };

  Future<void> _confirmDelete(SavedContent entry) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(entry.isPreset
            ? l10n.deletePresetConfirmMessage
            : l10n.deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.delete(entry);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contentsTitle),
        actions: [
          // The add control (011 FR-015): named by its tooltip, like the row
          // deletes — a list-wide action, never a row's own text.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addContentButton,
            onPressed: () =>
                Navigator.of(context).pop(const NewContentRequest()),
          ),
        ],
      ),
      body: FutureBuilder<List<_Row>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.storageErrorMessage),
              ),
            );
          }
          final rows = snapshot.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noContentsMessage),
              ),
            );
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final entry = row.entry;
              return ListTile(
                // One line always: a long auto-generated title is cut with an
                // ellipsis rather than wrapping into the subtitle (spec 008).
                title: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(entry.damaged
                    ? l10n.damagedContentMessage
                    : '${_languageLabel(l10n, entry.language)} · '
                        '${MaterialLocalizations.of(context).formatShortDate(entry.updatedAt.toLocal())}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.deleteButton,
                  onPressed: () => _confirmDelete(entry),
                ),
                onTap: () => Navigator.of(context).pop(PickedContent(entry)),
              );
            },
          );
        },
      ),
    );
  }
}
