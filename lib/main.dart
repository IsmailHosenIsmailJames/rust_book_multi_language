// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:rust_book/src/download/choice_language/choice_language.dart';
import 'package:rust_book/src/download/getzip/get_zip.dart';
import 'package:rust_book/src/web_view/web_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> autoRoute() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString("language");
    if (data == null) {
      FlutterNativeSplash.remove();
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ChoiceLanguage(),
          ),
          (route) => false);
    } else {
      final isDownloaded = prefs.getBool("isDownloaded");
      FlutterNativeSplash.remove();

      if (isDownloaded == null) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => GetZipFile(language: data),
            ),
            (route) => false);
      } else {
        final initUrl = prefs.getString("last_url");
        if (initUrl != null) {
          FlutterNativeSplash.remove();

          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewInApp(initialRoute: initUrl),
              ),
              (route) => false);
        } else {
          // TODO
          // get initial url using language selected
          String initUrl = "//TODO";
          FlutterNativeSplash.remove();

          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => WebViewInApp(initialRoute: initUrl),
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
