import 'package:flutter/material.dart';
import 'package:rust_book/src/download/choice_language/all_zip_info.dart';

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
            const Color.fromARGB(255, 151, 255, 203).withOpacity(0.6),
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
              const Color.fromARGB(255, 151, 255, 203).withOpacity(0.6),
              const Color.fromARGB(255, 136, 103, 255).withOpacity(0.6)
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Divider(
                thickness: 2,
              ),
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
                                    builder: (context) => Dialog(
                                      child: Container(
                                        height: 200,
                                        child: const Padding(
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
    );
  }
}
