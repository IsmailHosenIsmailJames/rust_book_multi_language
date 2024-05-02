import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:rust_book/src/download/choice_language/all_zip_info.dart';
import 'package:rust_book/src/download/getzip/get_zip.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChoiceLanguage extends StatefulWidget {
  const ChoiceLanguage({super.key});

  @override
  State<ChoiceLanguage> createState() => _ChoiceLanguageState();
}

class _ChoiceLanguageState extends State<ChoiceLanguage> {
  int selectedValue = 2;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            const Color.fromARGB(255, 103, 177, 140).withOpacity(0.6),
        title: const Center(
          child: Text(
            "Select A Language",
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
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
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: zipFilesWithInfo.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          selectedValue = index;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: index == selectedValue
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        height: 45,
                        child: Row(
                          children: [
                            index == selectedValue
                                ? Checkbox.adaptive(
                                    value: index == selectedValue,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedValue = index;
                                      });
                                    },
                                  )
                                : const SizedBox(
                                    width: 48,
                                  ),
                            Text(
                              zipFilesWithInfo[index]['language'],
                              style: const TextStyle(fontSize: 20),
                            ),
                            const Spacer(),
                            if (zipFilesWithInfo[index]['isComplete'] == false)
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const Dialog(
                                      child: SizedBox(
                                        height: 200,
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Center(
                                            child: Text(
                                              "Full translation not yet finished.\nSome content are still in English",
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.info_outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          String lan = zipFilesWithInfo[selectedValue]['language'];
          String url = zipFilesWithInfo[selectedValue]['link'];
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          final List<ConnectivityResult> connectivityResult =
              await (Connectivity().checkConnectivity());
          if (connectivityResult.contains(ConnectivityResult.mobile) ||
              connectivityResult.contains(ConnectivityResult.bluetooth) ||
              connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.vpn)) {
            await prefs.setString("zipLink", url);
            await prefs.setString("language", lan);
            Navigator.pushAndRemoveUntil(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(
                  builder: (context) => GetZipFile(
                      language: languageList.indexOf(lan).toString(),
                      urlOfZip: url),
                ),
                (route) => false);
          } else {
            showDialog(
              // ignore: use_build_context_synchronously
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Need internet connection."),
                content: const Text(
                    "This application will get download Rust Book in your selected language. So, in this step only, this application need internet connection. Please enable your internet connection"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
        },
        label: const Row(
          children: [
            Text(
              "NEXT ",
              style: TextStyle(fontSize: 16),
            ),
            Icon(
              Icons.arrow_forward,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
