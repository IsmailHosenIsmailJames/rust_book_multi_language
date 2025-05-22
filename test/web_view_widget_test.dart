import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart'; // For home icon if needed in tests
import 'package:rust_book/src/web_view/web_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// It's good practice to have a common setup for tests that need MaterialApp
// and potentially other common ancestors.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper function to pump WebViewInApp
  Future<void> pumpWebView(WidgetTester tester, {
    required List<String> htmls,
    String initialRoute = 'file:///android_asset/flutter_assets/book/index.html', // Valid URI
    String language = '0', // Corresponds to an index in languageList
  }) async {
    // Mock SharedPreferences because WebViewInApp accesses it during initState and actions
    SharedPreferences.setMockInitialValues({
      // Example: If you need to mock specific initial values:
      // 'language': 'English', // Actual language name
      // 'last_url': initialRoute,
    });

    await tester.pumpWidget(MaterialApp(
      home: WebViewInApp(
        initialRoute: initialRoute,
        language: language, // This is the language index string
        htmls: htmls,
      ),
    ));
  }

  group('WebViewInApp ToC Tests', () {
    testWidgets('ToC button is present and opens dialog', (WidgetTester tester) async {
      await pumpWebView(tester, htmls: ['chapter_1.html']);
      await tester.pumpAndSettle(); // Allow WebView to initialize if it has async init work

      // Verify ToC button is present
      expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget);
      expect(find.widgetWithTooltip(IconButton, 'Table of Contents'), findsOneWidget);

      // Tap the ToC button
      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle(); // Allow dialog to animate and settle

      // Verify dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Table of Contents'), findsOneWidget); // Dialog title
    });

    testWidgets('ToC dialog displays formatted items from htmls list', (WidgetTester tester) async {
      final testHtmls = ['section_alpha.html', 'another/section_beta.html', 'with-hyphens.html', 'all_caps.HTML'];
      await pumpWebView(tester, htmls: testHtmls);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      // Verify items are displayed with formatted names based on _formatTocEntryName logic
      expect(find.widgetWithText(ListTile, 'Section Alpha'), findsOneWidget);
      // _formatTocEntryName takes the last part of path: 'another/section_beta.html' -> 'Section Beta'
      expect(find.widgetWithText(ListTile, 'Section Beta'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'With Hyphens'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'All Caps'), findsOneWidget);
    });

    testWidgets('ToC item tap closes dialog (basic interaction)', (WidgetTester tester) async {
      await pumpWebView(tester, htmls: ['chapter_1.html', 'chapter_2.html']);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget); // Ensure dialog is open

      // Tap the first item in the ToC
      // This assumes 'chapter_1.html' becomes 'Chapter 1'
      await tester.tap(find.widgetWithText(ListTile, 'Chapter 1'));
      await tester.pumpAndSettle(); // Allow dialog to close and animations to settle

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);

      // Bonus: Open again and tap another item
      await tester.tap(find.byIcon(Icons.list_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Chapter 2'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    // Test for correct path loading on ToC item tap would require more complex mocking
    // of InAppWebViewController or platform channels, which is outside the typical
    // scope of widget tests without significant test infrastructure changes or refactoring
    // the widget for easier mock injection.
    // For now, we trust that if Navigator.pop is called, the onTap handler logic
    // for loading the URL was also invoked.
  });
}
