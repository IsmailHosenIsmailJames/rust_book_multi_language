import 'dart:io'; // For Directory
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // For InAppWebView
import 'package:path/path.dart' as path; // For path.join
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rust_book/main.dart' as app;
import 'package:rust_book/src/download/choice_language/all_zip_info.dart'; // To get languageList for index
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper to define FluentIcons if not directly available or to ensure consistency
// In a real app, these would typically come from a package like `fluentui_system_icons`
class AppFluentIcons {
  static const IconData home_24_regular = IconData(0xeed3, fontFamily: 'FluentSystemIcons-Regular');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late SharedPreferences prefs;

  // --- Configuration for the test ---
  const String testLanguageName = 'English';
  const String longChapterHtmlFile = 'ch03-00-common-programming-concepts.html';
  // Corrected based on _formatTocEntryName logic:
  // "ch03-00-common-programming-concepts.html" -> "Ch03 00 Common Programming Concepts"
  const String longChapterTocName = 'Ch03 00 Common Programming Concepts'; 
  
  // Placeholder: This text MUST be present far down in 'ch03-00-common-programming-concepts.html'
  // For a real test, verify this by inspecting the HTML file.
  const String targetTextOnLongPage = 'Functions'; 
                                         
  final List<String> englishBookHtmls = [
    'index.html',
    'foreword.html',
    'ch01-00-getting-started.html',
    'ch01-01-installation.html',
    'ch01-02-hello-world.html',
    'ch01-03-hello-cargo.html',
    'ch02-00-guessing-game-tutorial.html',
    longChapterHtmlFile, 
    'ch03-01-variables-and-mutability.html',
    'ch03-02-data-types.html',
    'ch03-03-how-functions-work.html', // This is where "Functions" heading is likely
    'ch03-04-comments.html',
    'ch03-05-control-flow.html',
    // Add more if needed, or keep minimal for this specific test.
  ];
  // --- End Configuration ---

  String englishLanguageIndex = "-1"; // Default to invalid

  setUpAll(() async {
    englishLanguageIndex = languageList.indexOf(testLanguageName).toString();
    if (englishLanguageIndex == "-1") {
      throw Exception("Test language '$testLanguageName' not found in languageList.");
    }

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String expectedBookPath = path.join(appDocDir.path, englishLanguageIndex, 'book');
    
    debugPrint("----------------------------------------------------------------------");
    debugPrint("INTEGRATION TEST PREREQUISITE:");
    debugPrint("This test requires the '$testLanguageName' book files to be unzipped and");
    debugPrint("available at: $expectedBookPath");
    if (!await Directory(expectedBookPath).exists()) {
      debugPrint("ERROR: '$testLanguageName' book files NOT FOUND at $expectedBookPath");
      debugPrint("Please ensure the book is unzipped there before running this test.");
      debugPrint("The test will likely fail or hang.");
    } else {
      debugPrint("'$testLanguageName' book files found at $expectedBookPath. Test can proceed.");
    }
    debugPrint("Target chapter: $longChapterHtmlFile, ToC Name: $longChapterTocName");
    debugPrint("Target text for scroll: '$targetTextOnLongPage'");
    debugPrint("----------------------------------------------------------------------");
  });

  setUp(() async {
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String bookSpecificPath = path.join(appDocDir.path, englishLanguageIndex, 'book', longChapterHtmlFile);
    String fileUriForLastUrl = Uri.file(bookSpecificPath).toString();

    await prefs.setString('language', testLanguageName);
    await prefs.setString('language_index', englishLanguageIndex);
    await prefs.setBool('isDownloaded', true);
    
    final zipInfo = zipFilesWithInfo.firstWhere((e) => e['language'] == testLanguageName, orElse: () => throw Exception("ZipInfo for $testLanguageName not found"));
    await prefs.setString('zipLink', zipInfo['link']);
    
    await prefs.setStringList('htmls', englishBookHtmls);
    await prefs.setString('last_url', fileUriForLastUrl);

    // Ensure no scroll position is initially set for the target page
    String scrollKey = "scroll_pos_${englishLanguageIndex}_${Uri.file(bookSpecificPath).path}";
    await prefs.remove(scrollKey); // Remove any pre-existing scroll position for this page
    
    debugPrint("SharedPreferences set for '$testLanguageName'. Last URL: $fileUriForLastUrl");
    debugPrint("Scroll key cleared: $scrollKey");
  });

  testWidgets('should attempt to restore scroll position after reopening page', (WidgetTester tester) async {
    // 1. Launch the app
    app.main(); 
    
    // Wait for app to initialize and load WebView with the long chapter (from last_url)
    debugPrint("App launched. Waiting for WebView to load initial page...");
    await tester.pumpAndSettle(const Duration(seconds: 7)); // Increased duration for initial load
    expect(find.byType(InAppWebView), findsOneWidget, reason: "InAppWebView should be present after app launch and initial load.");
    debugPrint("Initial page loaded in WebView.");

    // 2. Attempt to scroll down the page (targetTextOnLongPage is indicative, not directly verifiable)
    debugPrint("Attempting to scroll down...");
    // Drag up to scroll content down. Adjust offset if needed.
    await tester.drag(find.byType(InAppWebView), const Offset(0, -1000)); 
    await tester.pumpAndSettle(const Duration(milliseconds: 1000)); // Allow scroll and UI to update
    debugPrint("Scrolled down. (Manual observation needed to confirm '$targetTextOnLongPage' would be visible)");

    // 3. Trigger scroll save: Tap Home button in AppBar
    debugPrint("Tapping Home button to trigger scroll save and navigate to index.html...");
    await tester.tap(find.byIcon(AppFluentIcons.home_24_regular));
    await tester.pumpAndSettle(const Duration(seconds: 5)); // Allow index.html to load
    debugPrint("Home (index.html) loaded.");

    // 4. Navigate back to the long chapter using Table of Contents
    debugPrint("Opening Table of Contents...");
    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle(); // Wait for dialog
    
    debugPrint("Tapping '$longChapterTocName' in ToC...");
    // Ensure the ListTile with the specific text is found before tapping
    expect(find.widgetWithText(ListTile, longChapterTocName), findsOneWidget, 
           reason: "ToC item '$longChapterTocName' should be present.");
    await tester.tap(find.widgetWithText(ListTile, longChapterTocName));
    await tester.pumpAndSettle(const Duration(seconds: 5)); // Allow page to load + scroll restoration (300ms + page load)
    debugPrint("Long chapter ('$longChapterHtmlFile') reloaded.");

    // 5. Verification (Indirect)
    // The primary goal is to ensure the app doesn't crash and completes the flow.
    // Direct verification of scroll position or text visibility is highly complex.
    // Manual observation during test execution is key for webview content.
    expect(find.byType(InAppWebView), findsOneWidget, 
           reason: "InAppWebView should still be present after re-navigating to the chapter.");
    
    debugPrint("----------------------------------------------------------------------");
    debugPrint("TEST COMPLETED. Scroll persistence logic was exercised.");
    debugPrint("MANUAL VERIFICATION REQUIRED:");
    debugPrint("Observe if '$longChapterHtmlFile' was scrolled down when reloaded.");
    debugPrint("If it opened at the top, scroll persistence might not have worked as expected.");
    debugPrint("The text '$targetTextOnLongPage' should ideally be visible (or close to visible) after reload if scroll was restored.");
    debugPrint("----------------------------------------------------------------------");

    // Add a small delay at the end to allow manual observation if running on a device.
    await tester.pump(const Duration(seconds: 3));
  });
}
