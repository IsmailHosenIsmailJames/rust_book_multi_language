import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust_book/src/web_view/show_toawest_massage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

import 'list_of_html_files.dart';

class WebViewInApp extends StatefulWidget {
  final String initialRoute;
  final String language;
  const WebViewInApp(
      {super.key, required this.initialRoute, required this.language});

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
  String url = "";
  double progress = 0;
  Widget initWiget = const Center(
    child: CircularProgressIndicator(),
  );

  void initLastWebUrl() async {
    String initUrl = widget.initialRoute;
    makeAppBarTitle(initUrl);
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
          setState(() {
            this.url = url.toString();
          });
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          if (url != null) {
            await prefs.setString("last_url", url.toString());
          }
          makeAppBarTitle(url.toString());
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          var uri = navigationAction.request.url!;

          if (![
            "http",
            "https",
            "file",
            "chrome",
            "data",
            "javascript",
            "about"
          ].contains(uri.scheme)) {
            if (await canLaunchUrl(uri)) {
              // Launch the App
              await launchUrl(
                uri,
              );
              // and cancel the request
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {
          pullToRefreshController?.endRefreshing();
          setState(() {
            this.url = url.toString();
          });
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
        onUpdateVisitedHistory: (controller, url, isReload) {
          setState(() {
            this.url = url.toString();
          });
        },
        onConsoleMessage: (controller, consoleMessage) {},
      );
    });
  }

  @override
  void initState() {
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
  void dispose() {
    super.dispose();
  }

  String appBarTitile = "";

  void makeAppBarTitle(String url) {
    if (url.startsWith("file")) {
      List partsOfURL = url.split("/");
      List toBeShow = partsOfURL.sublist(6);
      String showString = toBeShow.toString();
      showString = showString
          .replaceAll(" ", "")
          .replaceAll("[", "")
          .replaceAll("]", "")
          .replaceAll(",", "/");
      setState(() {
        appBarTitile = showString;
      });
    } else {
      setState(() {
        appBarTitile = url;
      });
    }
    setState(() {
      showSearchBar = false;
      appBarSeacrchIcon = Icons.search;
    });
  }

  TextEditingController searchController = TextEditingController();
  TextEditingValue textEditingValue = const TextEditingValue();
  bool showSearchBar = false;
  IconData appBarSeacrchIcon = Icons.search;
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
          toolbarHeight: 65,
          title: showSearchBar
              ? Autocomplete<String>(
                  optionsMaxHeight: 500,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      onEditingComplete: onFieldSubmitted,
                      decoration: InputDecoration(
                          hintText: "Search document",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100))),
                    );
                  },
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return allHTMLFilesPathSorted.where((String option) {
                      return option
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) async {
                    Directory docDir = await getApplicationDocumentsDirectory();
                    Uri uriFilePath = Uri.file(path.join(
                        docDir.path, widget.language, "book", selection));
                    print("object- : ${uriFilePath.path}");
                    webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(uriFilePath.path)));
                  },
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: Text(appBarTitile)),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  showSearchBar = !showSearchBar;
                  appBarSeacrchIcon = showSearchBar
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.search;
                });
              },
              icon: Icon(appBarSeacrchIcon),
            ),
          ],
        ),
        // drawer: Drawer(),
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
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color.fromARGB(70, 50, 50, 50),
          onPressed: () {},
          label: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await webViewController?.goBack();
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () async {
                  await webViewController?.goForward();
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await webViewController?.reload();
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.home,
                ),
                onPressed: () async {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  String homePage = prefs.getString("home_page") ??
                      "file:///android_asset/flutter_assets/assets/index.html";
                  await webViewController?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(homePage),
                    ),
                  );
                },
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Text(
                          "Set as your Home page",
                        ),
                      ],
                    ),
                    onTap: () async {
                      final webUri = await webViewController?.getUrl();
                      String currentURL = webUri.toString();
                      final SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.setString("home_page", currentURL);
                      showToast("Set this as your Home page done.");
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Text(
                          "Go to defult home page",
                        ),
                      ],
                    ),
                    onTap: () async {
                      webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(
                              "file:///android_asset/flutter_assets/assets/index.html"),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
