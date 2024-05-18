import 'dart:collection';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

import '../download/choice_language/all_zip_info.dart';

class WebViewInApp extends StatefulWidget {
  final List<String> htmls;
  final String initialRoute;
  final String language;
  const WebViewInApp(
      {super.key,
      required this.initialRoute,
      required this.language,
      required this.htmls});

  @override
  WebViewInAppState createState() => WebViewInAppState();
}

class WebViewInAppState extends State<WebViewInApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;

  late ContextMenu contextMenu;
  double progress = 0;
  Widget initWiget = const Center(
    child: CircularProgressIndicator(),
  );

  void initLastWebUrl() async {
    String initUrl = widget.initialRoute;
    setState(() {
      initWiget = InAppWebView(
        key: webViewKey,
        // initialFile: initUrl,
        initialUrlRequest: URLRequest(url: WebUri(initUrl)),
        // initialUrlRequest:
        // URLRequest(url: WebUri(Uri.base.toString().replaceFirst("/#/", "/") + 'page.html')),
        // initialFile: "assets/index.html",
        initialUserScripts: UnmodifiableListView<UserScript>([]),
        initialSettings: settings,
        contextMenu: contextMenu,
        pullToRefreshController: pullToRefreshController,
        onWebViewCreated: (controller) async {
          webViewController = controller;
        },
        onLoadStart: (controller, url) async {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          if (url != null) {
            await prefs.setString("last_url", url.toString());
          }
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT);
        },

        onReceivedError: (controller, request, error) {
          pullToRefreshController?.endRefreshing();
        },
        onProgressChanged: (controller, progress) {
          if (progress == 100) {
            pullToRefreshController?.endRefreshing();
          }
          setState(() {
            this.progress = progress / 100;
          });
        },
      );
    });
  }

  @override
  void initState() {
    FlutterNativeSplash.remove();
    super.initState();
    contextMenu = ContextMenu(
      menuItems: [
        ContextMenuItem(
            id: 1,
            title: "Special",
            action: () async {
              await webViewController?.clearFocus();
            })
      ],
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: false),
      onCreateContextMenu: (hitTestResult) async {},
    );

    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );

    initLastWebUrl();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        bool? canPop = await webViewController?.canGoBack();
        if (canPop == true) {
          webViewController?.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          toolbarHeight: 43,
          title: Row(
            children: [
              IconButton(
                onPressed: () async {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  String? language = prefs.getString("language");
                  language = languageList.indexOf(language!).toString();
                  Directory docDir = await getApplicationDocumentsDirectory();
                  String? home = prefs.getString("home");
                  if (home == null) {
                    String indexPath =
                        path.join(docDir.path, language, "book/index.html");

                    webViewController?.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(indexPath),
                      ),
                    );
                  } else {
                    webViewController?.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(home),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  FluentIcons.home_24_regular,
                ),
              ),
              Expanded(
                child: Autocomplete<String>(
                  optionsMaxHeight: 380,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    return SizedBox(
                      height: 38,
                      child: CupertinoSearchTextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                      ),
                    );
                  },
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return widget.htmls.where((String option) {
                      return option
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) async {
                    final SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    Directory docDir = await getApplicationDocumentsDirectory();
                    String? language = prefs.getString("language");
                    language = languageList.indexOf(language!).toString();
                    String indexPath = path.join(
                      docDir.path,
                      language,
                      "book",
                      selection,
                    );
                    webViewController?.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(
                          indexPath,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              SizedBox(
                height: 30,
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (await webViewController!.canGoBack()) {
                      webViewController!.goBack();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                width: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (await webViewController!.canGoForward()) {
                      webViewController!.goForward();
                    }
                  },
                  icon: const Icon(
                    Icons.arrow_forward,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                width: 40,
                child: PopupMenuButton(
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(FluentIcons.home_24_regular),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "Set as home",
                            ),
                          ],
                        ),
                        onTap: () async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String? language = prefs.getString("language");
                          language = languageList.indexOf(language!).toString();
                          var x = await webViewController?.getUrl();
                          await prefs.setString("home", x!.path);
                        },
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.restore),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              "Reset home",
                            ),
                          ],
                        ),
                        onTap: () async {
                          final SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String? language = prefs.getString("language");
                          language = languageList.indexOf(language!).toString();
                          Directory docDir =
                              await getApplicationDocumentsDirectory();
                          String indexPath = path.join(
                              docDir.path, language, "book/index.html");

                          await prefs.setString("last_url", indexPath);

                          await prefs.setString("home", indexPath);
                          webViewController!.loadUrl(
                              urlRequest: URLRequest(url: WebUri(indexPath)));
                        },
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: [
                    initWiget,
                    progress < 1.0
                        ? LinearProgressIndicator(value: progress)
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
