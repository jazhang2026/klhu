import 'package:flutter/material.dart';
import 'package:klhu/appearance_store.dart';
import 'package:klhu/l10n/app_localizations.dart';

/// The appearance screen (spec 011 US2): the reading page's own text previewed
/// in the candidate typeface and size.
///
/// Confirming pops the chosen [ReadingAppearance]; going back pops nothing, so
/// a preview the user abandons never reaches the store (FR-008, contract
/// § Write protocol).
class AppearanceScreen extends StatefulWidget {
  /// The appearance in force when the screen opened — the candidate's start.
  final ReadingAppearance initial;

  /// The text to preview: the reading page's own text, so the reader judges the
  /// face and the size on what they are actually reading.
  final String previewText;

  const AppearanceScreen({
    super.key,
    required this.initial,
    required this.previewText,
  });

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late ReadingTypeface _typeface = widget.initial.typeface;
  late ReadingSize _size = widget.initial.size;

  /// The candidate as it renders: the preview here and (on confirm) the page
  /// share these two fields, so what the reader sees is what they get.
  TextStyle _previewStyle(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium!;
    return body.copyWith(
      fontFamily: _typeface.familyFor(Theme.of(context).platform),
      fontSize: _size.points,
    );
  }

  String _faceLabel(AppLocalizations l10n, ReadingTypeface face) =>
      switch (face.name) {
        'serif' => l10n.fontSerifLabel,
        'mono' => l10n.fontMonoLabel,
        _ => l10n.fontDefaultLabel,
      };

  String _sizeLabel(AppLocalizations l10n, ReadingSize size) =>
      switch (size.name) {
        'small' => l10n.sizeSmallLabel,
        'large' => l10n.sizeLargeLabel,
        'xlarge' => l10n.sizeXLargeLabel,
        _ => l10n.sizeMediumLabel,
      };

  /// One option row: the offered set as chips, the one in force selected.
  Widget _optionRow({
    required String title,
    required List<Widget> chips,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: chips),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final preview = widget.previewText.isEmpty ? 'Aa' : widget.previewText;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceTitle),
        actions: [
          // The explicit confirm: the page above changes on it, and nothing
          // else does (FR-008).
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ReadingAppearance(typeface: _typeface, size: _size),
            ),
            child: Text(l10n.doneButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.previewLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(preview, style: _previewStyle(context)),
          ),
          const SizedBox(height: 24),
          _optionRow(
            title: l10n.fontLabel,
            chips: [
              for (final face in ReadingTypeface.all)
                ChoiceChip(
                  label: Text(_faceLabel(l10n, face)),
                  selected: face.name == _typeface.name,
                  onSelected: (_) => setState(() => _typeface = face),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _optionRow(
            title: l10n.sizeLabel,
            chips: [
              for (final size in ReadingSize.all)
                ChoiceChip(
                  label: Text(_sizeLabel(l10n, size)),
                  selected: size.name == _size.name,
                  onSelected: (_) => setState(() => _size = size),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
