import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rust_book/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GetZipFile extends StatefulWidget {
  final String language;
  final String urlOfZip;
  const GetZipFile({super.key, required this.language, required this.urlOfZip});

  @override
  State<GetZipFile> createState() => _GetZipFileState();
}

class _GetZipFileState extends State<GetZipFile> {
  Widget toShow = const Text(
    "Getting Start",
    style: TextStyle(fontSize: 20),
  );

  void getZipFileDownloaded() async {
    try {
      setState(() {
        toShow = const Text(
          "Downloading...\nCompressed File size 4.4 MB only",
          style: TextStyle(fontSize: 20),
        );
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final response = await http.get(Uri.parse(widget.urlOfZip));
      if (response.statusCode == 200) {
        final Directory docDir = await getApplicationDocumentsDirectory();
        String fullPath = path.join(docDir.path, "${widget.language}.zip");
        File toSaveFile = File(fullPath);
        await toSaveFile.writeAsBytes(response.bodyBytes);
        await prefs.setBool("isDownloaded", true);

        try {
          List<String> htmlPath = [];
          await ZipFile.extractToDirectory(
            zipFile: toSaveFile,
            destinationDir: Directory(path.join(docDir.path, widget.language)),
            onExtracting: (zipEntry, progress) {
              if (zipEntry.name.endsWith(".html")) {
                htmlPath.add(zipEntry.name.replaceAll("book/", ""));
              }
              setState(() {
                toShow = Text(
                  "Extracting Compressed Files : ${progress.round()}%",
                  style: const TextStyle(fontSize: 20),
                );
              });
              return ZipFileOperation.includeItem;
            },
          );
          await prefs.setStringList("htmls", htmlPath);
          await toSaveFile.delete();
          setState(() {
            toShow = const Text(
              "Awesome... Al is done",
              style: TextStyle(fontSize: 20),
            );
          });
          Navigator.pushAndRemoveUntil(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(
                builder: (context) => const InitRoute(),
              ),
              (route) => false);
        } catch (e) {
          showErrorDialog("Error occoured when extracting files");
        }
      }
    } catch (e) {
      showErrorDialog("Error occoured when downloading files");
    }
  }

  void showErrorDialog(String errorText) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error Occoured"),
          content: Text(errorText),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pop();
              },
              child: const Text("Cancle"),
            ),
            TextButton(
              onPressed: () {
                getZipFileDownloaded();
                Navigator.pop(context);
              },
              child: const Text("Retry"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    getZipFileDownloaded();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 103, 177, 140).withOpacity(0.6),
              const Color.fromARGB(255, 136, 103, 255).withOpacity(0.6)
            ],
          ),
        ),
        child: Center(
          child: toShow,
        ),
      ),
    );
  }
}
