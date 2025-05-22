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
import 'package:rust_book/main.dart';
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
      iframeAllow: 'camera; microphone',
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
          // Original 'last_url' saving logic is moved to onLoadStop for better consistency with scroll saving.
          // final SharedPreferences prefs = await SharedPreferences.getInstance();
          // if (url != null) {
          //   await prefs.setString('last_url', url.toString());
          // }
        },
        onLoadStop: (controller, url) async {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          if (url != null) {
            // Restore scroll position
            String scrollKey = "scroll_pos_${widget.language}_${url.path}";
            int? savedScrollY = prefs.getInt(scrollKey);
            if (savedScrollY != null) {
              Future.delayed(const Duration(milliseconds: 300), () {
                controller.scrollTo(x: 0, y: savedScrollY, animated: false);
              });
            }

            // Save the 'last_url'
            await prefs.setString('last_url', url.toString());

            // Save the initial scroll position for the currently loaded page
            // (it might be 0 or some other value if the page auto-scrolls on load)
            int? currentScrollY = await controller.getScrollY();
            if (currentScrollY != null) {
              await prefs.setInt(scrollKey, currentScrollY);
              // print("Saved initial scroll $currentScrollY for $scrollKey"); // For debugging
            }
          }
          // Note: The progress update logic originally in the prompt for onLoadStop
          // is actually part of onProgressChanged in the existing code.
          // We should not duplicate it here.
        },
        onUpdateVisitedHistory: (controller, url, androidIsReload) async {
          await _saveCurrentScrollPosition();
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
            title: 'Special',
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
          leading: IconButton(
            icon: const Icon(FluentIcons.home_24_regular),
            onPressed: () async {
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              // String? languagePref = prefs.getString('language'); // Not needed directly, widget.language is the index
              Directory docDir = await getApplicationDocumentsDirectory();
              String? home = prefs.getString('home');
              if (home == null) {
                // Use widget.language (which is the language index string) for path
                String indexPath = path.join(docDir.path, widget.language, 'book/index.html');
                webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(indexPath)));
              } else {
                webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(home)));
              }
            },
          ),
          title: Autocomplete<String>(
            optionsMaxHeight: 380,
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              return SizedBox(
                height: 38, // Ensure consistent height
                child: CupertinoSearchTextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            },
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return widget.htmls.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) async {
              final Directory docDir = await getApplicationDocumentsDirectory();
              // Use widget.language (which is the language index string) for path
              String indexPath = path.join(
                docDir.path,
                widget.language,
                'book',
                selection,
              );
              webViewController?.loadUrl(
                urlRequest: URLRequest(url: WebUri(indexPath)),
              );
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.list_alt_outlined), // Or FluentIcons.bullet_list_24_regular
              tooltip: 'Table of Contents',
              onPressed: () {
                _showTableOfContents(context);
              },
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
                icon: const Icon(Icons.arrow_back, size: 18),
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
                icon: const Icon(Icons.arrow_forward, size: 18),
              ),
            ),
            SizedBox(
              height: 30,
              width: 40, // Retain original width for PopupMenuButton
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                itemBuilder: (context) {
                  return [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(FluentIcons.home_24_regular),
                          SizedBox(width: 10),
                          Text('Set as home'),
                        ],
                      ),
                      onTap: () async {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        // var x = await webViewController?.getUrl(); // Not language, but current URL path
                        // await prefs.setString('home', x!.path);
                        WebUri? currentUrl = await webViewController?.getUrl();
                        if (currentUrl != null) {
                          await prefs.setString('home', currentUrl.toString());
                        }
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.restore),
                          SizedBox(width: 10),
                          Text('Reset home'),
                        ],
                      ),
                      onTap: () async {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        Directory docDir = await getApplicationDocumentsDirectory();
                        // Use widget.language for path
                        String indexPath = path.join(docDir.path, widget.language, 'book/index.html');
                        await prefs.setString('last_url', indexPath); // Also reset last_url to home
                        await prefs.setString('home', indexPath);
                        webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(indexPath)));
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.restart_alt_rounded),
                          SizedBox(width: 10),
                          Text('Reset App'),
                        ],
                      ),
                      onTap: () async {
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        Directory docDir = await getApplicationDocumentsDirectory();
                        // Use widget.language for path
                        Directory directory = Directory(path.join(docDir.path, widget.language));
                        await deleteFolder(directory); // Ensure deleteFolder is accessible or defined in this scope
                        await prefs.clear();

                        Navigator.pushAndRemoveUntil(
                          // ignore: use_build_context_synchronously
                          context,
                          MaterialPageRoute(builder: (context) => const InitRoute()), // Ensure InitRoute is imported
                          (route) => true,
                        );
                      },
                    ),
                  ];
                },
              ),
            ),
          ],
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

  Future<void> deleteFolder(Directory directory) async {
    if (await directory.exists()) {
      // List all entities inside the directory (files, subdirectories)
      final List<FileSystemEntity> entities = await directory.list().toList();

      // Iterate through the list of entities
      for (FileSystemEntity entity in entities) {
        if (entity is Directory) {
          // If the entity is a directory, call deleteFolder recursively
          await deleteFolder(entity);
        } else if (entity is File) {
          // If the entity is a file, delete it
          await entity.delete();
        }
      }

      // After deleting all contents, delete the directory itself
      await directory.delete();
    }
  }

  // New method to save current scroll position
  Future<void> _saveCurrentScrollPosition() async {
    if (webViewController != null) {
      WebUri? currentWebUri = await webViewController!.getUrl();
      int? scrollY = await webViewController!.getScrollY();
      if (currentWebUri != null && scrollY != null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String key = "scroll_pos_${widget.language}_${currentWebUri.path}";
        await prefs.setInt(key, scrollY);
        // print("Saved scroll $scrollY for $key"); // For debugging
      }
    }
  }

  @override
  void dispose() {
    // Save the final scroll position before the widget is disposed
    _saveCurrentScrollPosition();
    super.dispose();
  }

  // Function to format display names for ToC
  String _formatTocEntryName(String htmlFileName) {
    String name = htmlFileName;
    // Remove .html extension
    if (name.endsWith('.html')) {
      name = name.substring(0, name.length - '.html'.length);
    }
    // Get the last part of the path (filename without parent directories)
    name = name.split('/').last;
    // Replace underscores and hyphens with spaces
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    // Capitalize first letter of each word
    name = name.split(' ').map((word) {
      if (word.isEmpty) return '';
      // Ensure word is not just spaces before trying to access characters
      if (word.trim().isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
    // Specific rule for 'Print' as per example, could be generalized
    if (name == 'Print') {
      // Keep it simple as "Print Page" or just "Print" if no other context
      // For now, let's assume if it's 'print.html' it becomes 'Print'
    }
    return name;
  }

  void _showTableOfContents(BuildContext context) async {
    final Directory docDir = await getApplicationDocumentsDirectory();
    // widget.language is already the language index as a string, e.g., "0", "1", etc.

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Table of Contents'),
          content: SizedBox(
            width: double.maxFinite, // Use as much width as possible for the dialog
            child: ListView.builder(
              itemCount: widget.htmls.length,
              itemBuilder: (BuildContext listContext, int index) {
                String htmlFile = widget.htmls[index]; // e.g., "chapter_1.html" or "appendix/foo.html"
                String displayName = _formatTocEntryName(htmlFile);
                return ListTile(
                  title: Text(displayName),
                  onTap: () async {
                    String filePath = path.join(
                      docDir.path,
                      widget.language, // This is the language index string
                      'book',
                      htmlFile, // This is the relative path from 'book/'
                    );
                    webViewController?.loadUrl(
                      urlRequest: URLRequest(url: WebUri(filePath)), // File URI
                    );
                    Navigator.of(dialogContext).pop(); // Close the dialog
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
