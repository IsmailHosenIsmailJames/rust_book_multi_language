import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  String text = 'Getting Start';

  void getZipFileDownloaded() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Directory docDir = await getApplicationDocumentsDirectory();
      String fullPath = path.join(docDir.path, '${widget.language}.zip');
      Response response = await Dio().download(
        widget.urlOfZip,
        fullPath,
        onReceiveProgress: (count, total) {
          setState(() {
            setState(() {
              text = 'Downloading (${((count / total) * 100).toInt()})%';
            });
          });
        },
      );

      if (await File(fullPath).exists() && response.statusCode == 200) {
        String fullPath = path.join(docDir.path, '${widget.language}.zip');
        File toSaveFile = File(fullPath);
        await prefs.setBool('isDownloaded', true);

        try {
          List<String> htmlPath = [];
          final inputStream = InputFileStream(fullPath);
          final archive = ZipDecoder().decodeStream(inputStream);
          for (var file in archive.files) {
            if (file.isFile) {
              if (file.name.endsWith('.html')) {
                htmlPath.add(file.name.replaceAll('book/', ''));
              }
              final outputStream = OutputFileStream(
                  Directory(path.join(docDir.path, widget.language, file.name))
                      .path);
              file.writeContent(outputStream);
              await outputStream.close();
            }
          }

          await prefs.setStringList('htmls', htmlPath);
          await toSaveFile.delete();
          setState(() {
            text = 'Awesome... Al is done';
          });
          Navigator.pushAndRemoveUntil(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(
                builder: (context) => const InitRoute(),
              ),
              (route) => false);
        } catch (e) {
          showErrorDialog('Error occoured when extracting files');
        }
      }
    } catch (e) {
      showErrorDialog('Error occoured when downloading files');
    }
  }

  void showErrorDialog(String errorText) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error Occoured'),
          content: Text(errorText),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pop();
              },
              child: const Text('Cancle'),
            ),
            TextButton(
              onPressed: () {
                getZipFileDownloaded();
                Navigator.pop(context);
              },
              child: const Text('Retry'),
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
      body: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
