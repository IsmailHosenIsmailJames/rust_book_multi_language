import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        backgroundColor: Colors.grey,
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
