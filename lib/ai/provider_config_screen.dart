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
import 'package:klhu/ai/auto_test.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:klhu/ai/provider_list.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete provider'),
        content: Text('Delete "${provider.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
  Future<void> _selectProvider(AIProvider provider) async {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Providers'),
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
                              label: const Text('Add Provider'),
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
    final isPreset = AIProvider.presets.any((p) => p.name == provider.name);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: provider.active ? Colors.green : Colors.grey,
          child: Icon(
            provider.active ? Icons.check : Icons.help,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(provider.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.url,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (provider.registerTip.isNotEmpty)
              Text(
                provider.registerTip,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Row(
              children: [
                if (provider.active)
                  const Chip(
                    label: Text('Active'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (provider.selected) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('Selected'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPreset)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            if (!provider.selected)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: onSelect,
                tooltip: 'Select',
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
    return AlertDialog(
      title: const Text('Add Provider'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. My Custom Provider',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'e.g. https://api.example.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tipController,
              decoration: const InputDecoration(
                labelText: 'Registration Tip',
                hintText: 'How to get an API key...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectivity test failed. Please check the API key.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit: ${widget.provider.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.provider.registerTip.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.provider.registerTip,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your API key...',
              ),
              obscureText: true,
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
                          ? 'Connectivity test passed'
                          : 'Connectivity test failed',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _testAndSave,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & Test'),
        ),
      ],
    );
  }
}
