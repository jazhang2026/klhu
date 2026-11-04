/// 029 — the AI provider configuration screen (spec FR-001, FR-002, FR-003,
/// FR-004; data-model §1).
///
/// The top tool bar's Settings button opens this screen. The reader can:
/// - see the seeded presets and any user-added providers
/// - add a new provider (name + url)
/// - edit an existing provider's API key (which triggers an auto-connectivity test)
/// - delete a user-added provider
/// - mark one provider as `selected` (the default shown in the AI dialog)
///
/// A provider's `active` flag is set true only when the connectivity test
/// passes after adding or editing its API key (spec FR-004, Q7).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:klhu/ai/auto_test.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The AI provider configuration screen opened from the top tool bar's
/// Settings group (spec FR-001, FR-002, FR-003, FR-004).
class AIProviderConfigScreen extends StatefulWidget {
  const AIProviderConfigScreen({super.key});

  @override
  State<AIProviderConfigScreen> createState() => _AIProviderConfigScreenState();
}

class _AIProviderConfigScreenState extends State<AIProviderConfigScreen> {
  late Future<List<AIProvider>> _providersFuture;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _providersFuture = _loadProviders();
    _loadProviders().then((_) => setState(() => _loading = false));
  }

  Future<List<AIProvider>> _loadProviders() async {
    try {
      final store = AIConfigStore();
      return await store.load();
    } catch (e) {
      debugPrint('klhu AI provider config load failed: $e');
      setState(() => _error = 'Failed to load providers: $e');
      return [];
    }
  }

  Future<void> _saveProviders(List<AIProvider> providers) async {
    try {
      final store = AIConfigStore();
      await store.save(providers);
    } catch (e) {
      debugPrint('klhu AI provider config save failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.aiProviderFailSave(e.toString()))),
        );
      }
    }
  }

  /// Run the connectivity test for [provider] with [apiKey].
  /// Returns true if the test passed, false otherwise.
  Future<bool> _runConnectivityTest(AIProvider provider, String apiKey) async {
    final test = testFor(provider.url);
    if (test == null) return false;
    try {
      final result = await test.test(provider.url, apiKey);
      return result == TestResult.passed;
    } catch (_) {
      return false;
    }
  }

  /// Add a new provider to the list.
  Future<void> _addProvider() async {
    final result = await showDialog<AIProvider>(
      context: context,
      builder: (context) => _AddProviderDialog(),
    );
    if (result == null || !mounted) return;

    var providers = await _providersFuture;
    providers = [...providers, result];
    await _saveProviders(providers);
    _providersFuture = _loadProviders();
    setState(() {});
  }

  /// Edit an existing provider's API key, triggering the connectivity test.
  Future<void> _editProvider(AIProvider provider) async {
    final edited = await showDialog<AIProvider>(
      context: context,
      builder: (context) => _EditProviderDialog(provider: provider),
    );
    if (edited == null || !mounted) return;

    var providers = await _providersFuture;
    final index = providers.indexWhere((p) => p.name == provider.name);
    if (index < 0) return;

    // Run connectivity test if the API key changed or is new.
    if (edited.apiKey.isNotEmpty && edited.apiKey != provider.apiKey) {
      final passed = await _runConnectivityTest(edited, edited.apiKey);
      final updated = edited.copyWith(active: passed);
      providers[index] = updated;
    } else {
      providers[index] = edited;
    }
    await _saveProviders(providers);
    _providersFuture = _loadProviders();
    setState(() {});
  }

  /// Delete a user-added provider. Presets cannot be deleted.
  Future<void> _deleteProvider(AIProvider provider) async {
    final isPreset = AIProvider.presets.any((p) => p.name == provider.name);
    if (isPreset) return; // Presets cannot be deleted.

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiProviderDeleteTitle),
        content: Text(l10n.aiProviderDeleteConfirm(provider.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.aiProviderDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiProviderDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var providers = await _providersFuture;
    providers = providers.where((p) => p.name != provider.name).toList();
    await _saveProviders(providers);
    _providersFuture = _loadProviders();
    setState(() {});
  }

  /// Mark a provider as selected (the default shown in the AI dialog).
  /// Inactive providers cannot be selected — the user must first set an API
  /// key so the provider becomes active (spec Q9).
  Future<void> _selectProvider(AIProvider provider) async {
    if (!provider.active) return; // Inactive providers cannot be selected.
    var providers = await _providersFuture;
    providers = providers
        .map((p) => p.copyWith(selected: p.name == provider.name))
        .toList();
    await _saveProviders(providers);
    _providersFuture = _loadProviders();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiProviderTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : FutureBuilder<List<AIProvider>>(
                  future: _providersFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final providers = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: providers.length + 1, // +1 for the add button
                      itemBuilder: (context, index) {
                        if (index == providers.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: FilledButton.icon(
                              onPressed: _addProvider,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.aiProviderAddButton),
                            ),
                          );
                        }
                        return _ProviderTile(
                          provider: providers[index],
                          onEdit: () => _editProvider(providers[index]),
                          onDelete: () => _deleteProvider(providers[index]),
                          onSelect: () => _selectProvider(providers[index]),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

/// One provider entry in the configuration list.
class _ProviderTile extends StatelessWidget {
  final AIProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const _ProviderTile({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPreset = AIProvider.presets.any((p) => p.name == provider.name);
    final statusText = provider.selected && provider.active
        ? l10n.aiProviderStatusSelected
        : provider.active
            ? l10n.aiProviderStatusActive
            : null;
    final statusColor = provider.selected && provider.active
        ? Colors.green
        : provider.active
            ? Colors.blue
            : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: provider.active
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : const Icon(Icons.help, color: Colors.white, size: 20),
        ),
        title: Text(provider.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (statusText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Chip(
                  label: Text(statusText),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  side: BorderSide(color: statusColor, width: 1),
                ),
              ),
            // Only show the URL from the register tip (e.g. the API key setup
            // page), not the full instruction text.
            if (provider.registerTip.isNotEmpty)
              _RegisterTipLink(text: provider.registerTip),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPreset)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                tooltip: l10n.aiProviderDeleteTooltip,
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: l10n.aiProviderEditTooltip,
            ),
            if (!provider.active)
              const Icon(Icons.lock_outline, color: Colors.grey),
            if (!provider.selected && provider.active)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: onSelect,
                tooltip: l10n.aiProviderSelectTooltip,
              ),
            if (provider.selected)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

/// Dialog for adding a new provider.
class _AddProviderDialog extends StatefulWidget {
  const _AddProviderDialog();

  @override
  State<_AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<_AddProviderDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _tipController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) return;

    Navigator.pop(context, AIProvider(
      name: name,
      url: url,
      registerTip: _tipController.text.trim(),
      apiKey: '',
      active: false,
      selected: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.aiProviderAddButton),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.aiProviderNameLabel,
                hintText: l10n.aiProviderNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.aiProviderUrlLabel,
                hintText: l10n.aiProviderUrlHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tipController,
              decoration: InputDecoration(
                labelText: l10n.aiProviderTipLabel,
                hintText: l10n.aiProviderTipHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.aiProviderDeleteCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.aiProviderAddButton2),
        ),
      ],
    );
  }
}

/// Extracts URLs from [text] and makes them tappable via [url_launcher].
/// Only the URL itself is shown as a tappable link; surrounding instructional
/// text (e.g. "Go to ... and create a key") is hidden — the reader just sees
/// the link they can tap to open the setup page.
///
/// Falls back to plain text for non-URL content.
class _RegisterTipLink extends StatelessWidget {
  final String text;

  const _RegisterTipLink({required this.text});

  Future<void> _openUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    final currentContext = context;
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: url));
    if (!currentContext.mounted) return;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(l10n.aiClipboardCopiedMessage(url)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.aiClipboardOpenAction,
          onPressed: () async {
            if (currentContext.mounted && await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urlPattern = RegExp(r'https?://[^\s]+');
    final matches = urlPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    // Show the full tip text with the first URL as a tappable link.
    final firstUrl = matches.first.group(0)!;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: GestureDetector(
        onTap: () => _openUrl(firstUrl, context),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
        ),
      ),
    );
  }
}

/// Dialog for editing an existing provider's API key.
class _EditProviderDialog extends StatefulWidget {
  final AIProvider provider;

  const _EditProviderDialog({required this.provider});

  @override
  State<_EditProviderDialog> createState() => _EditProviderDialogState();
}

class _EditProviderDialogState extends State<_EditProviderDialog> {
  late final TextEditingController _apiKeyController;
  bool _saving = false;
  TestResult? _testResult;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.provider.apiKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final apiKey = _apiKeyController.text.trim();
    setState(() => _saving = true);

    final test = testFor(widget.provider.url);
    bool passed = false;
    if (test != null && apiKey.isNotEmpty) {
      final result = await test.test(widget.provider.url, apiKey);
      passed = result == TestResult.passed;
    }

    setState(() {
      _saving = false;
      _testResult = passed ? TestResult.passed : TestResult.failed;
    });

    if (!mounted) return;

    if (passed) {
      Navigator.pop(context, widget.provider.copyWith(
        apiKey: apiKey,
        active: true,
      ));
    } else {
      // Show error and let them try again.
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.aiConnectivityTestFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.aiEditProviderTitle(widget.provider.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.provider.registerTip.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RegisterTipLink(text: widget.provider.registerTip),
              ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: l10n.aiEditApiKeyLabel,
                hintText: l10n.aiEditApiKeyHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscureKey = !_obscureKey);
                  },
                  tooltip: _obscureKey ? 'Show key' : 'Hide key',
                ),
              ),
              obscureText: _obscureKey,
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      _testResult == TestResult.passed
                          ? Icons.check_circle
                          : Icons.error,
                      color: _testResult == TestResult.passed
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _testResult == TestResult.passed
                          ? l10n.aiTestPassed
                          : l10n.aiTestFailed,
                      style: TextStyle(
                        color: _testResult == TestResult.passed
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.aiProviderDeleteCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _testAndSave,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.aiEditSaveButton),
        ),
      ],
    );
  }
}
