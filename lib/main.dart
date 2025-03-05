// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust_book/src/download/choice_language/all_zip_info.dart';
import 'package:rust_book/src/download/choice_language/choice_language.dart';
import 'package:rust_book/src/download/getzip/get_zip.dart';
import 'package:rust_book/src/web_view/web_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

final localhostServer =
    InAppLocalhostServer(documentRoot: 'assets', port: 1502);
void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  if (!kIsWeb) {
    await localhostServer.start();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green, brightness: Brightness.dark)),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const InitRoute(),
    );
  }
}

class InitRoute extends StatefulWidget {
  const InitRoute({super.key});

  @override
  State<InitRoute> createState() => _InitRouteState();
}

class _InitRouteState extends State<InitRoute> {
  Future<void> autoRoute() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? language = prefs.getString('language');
    if (language == null) {
      FlutterNativeSplash.remove();
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ChoiceLanguage(),
          ),
          (route) => false);
    } else {
      language = languageList.indexOf(language).toString();
      final isDownloaded = prefs.getBool('isDownloaded');
      final link = prefs.getString('zipLink');
      FlutterNativeSplash.remove();

      if (isDownloaded == null) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => GetZipFile(
                language: language!,
                urlOfZip: link!,
              ),
            ),
            (route) => false);
      } else {
        Directory docDir = await getApplicationDocumentsDirectory();
        String? initUrl = prefs.getString('last_url');
        List<String>? htmls = prefs.getStringList('htmls');
        if (initUrl != null) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewInApp(
                  initialRoute: initUrl,
                  language: language!,
                  htmls: htmls ?? [],
                ),
              ),
              (route) => false);
        } else {
          String indexPath =
              path.join(docDir.path, language, 'book/index.html');
          Uri uriPath = Uri.file(indexPath);
          await prefs.setString('last_url', uriPath.path);

          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewInApp(
                  initialRoute: indexPath,
                  language: language!,
                  htmls: htmls ?? [],
                ),
              ),
              (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    autoRoute();
    return const Scaffold();
  }
}
