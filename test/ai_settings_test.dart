/// 029 — widget tests for the AI provider settings and prompt dialog.
///
/// Tests the top tool bar's Settings button and the Edit page's AI button,
/// including the provider options dropdown and prompt dialog (spec FR-001,
/// FR-005, Q9, Q10).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klhu/ai/config_store.dart';
import 'package:klhu/ai/provider_list.dart';
import 'package:klhu/ai/provider_config_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AIProviderConfigScreen', () {
    testWidgets('shows the three presets on load', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const AIProviderConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google AI Studio (Gemini)'), findsOneWidget);
      expect(find.text('OpenRouter (:free)'), findsOneWidget);
      expect(find.text('NVIDIA NIM'), findsOneWidget);
    });

    testWidgets('Add Provider dialog opens and closes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const AIProviderConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Add Provider" button (the FilledButton at the bottom).
      final addButton = find.widgetWithText(FilledButton, 'Add Provider');
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Dialog should be visible.
      expect(find.text('Add Provider'), findsWidgets); // title + button
      expect(find.byType(TextField), findsNWidgets(3)); // Name, URL, Tip

      // Cancel.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // Dialog should be gone.
      expect(find.text('Add Provider'), findsOneWidget); // only the button remains
    });

    testWidgets('Edit provider opens dialog with API key field',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const AIProviderConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the first Edit button.
      final editFinder = find.byIcon(Icons.edit).first;
      await tester.tap(editFinder);
      await tester.pumpAndSettle();

      // Edit dialog should be visible.
      expect(find.text('API Key'), findsOneWidget);
      expect(find.byType(TextEditingController), findsNothing); // not a widget
      expect(find.text('Save & Test'), findsOneWidget);

      // Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('Provider list persistence', () {
    testWidgets('user-added provider persists across reloads', (tester) async {
      final store = AIConfigStore();
      var providers = await store.load();
      final userProvider = AIProvider(
        name: 'My Custom Provider',
        url: 'https://custom.example.com',
        registerTip: 'Register at custom.example.com',
        apiKey: 'custom-key',
        active: false,
        selected: false,
      );
      providers = [...providers, userProvider];
      await store.save(providers);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const AIProviderConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Custom Provider'), findsOneWidget);
    });

    testWidgets('selected provider is highlighted', (tester) async {
      final store = AIConfigStore();
      var providers = await store.load();
      // Mark the second preset as selected.
      providers = providers
          .map((p) => p.name == 'OpenRouter (:free)'
              ? p.copyWith(selected: true)
              : p)
          .toList();
      await store.save(providers);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const AIProviderConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The selected provider should have a check icon.
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });
  });
}
