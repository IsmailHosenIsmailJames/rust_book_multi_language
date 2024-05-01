import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showToast(String massage) {
  Fluttertoast.showToast(
    msg: massage,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: Colors.grey[700],
    textColor: Colors.white,
    timeInSecForIosWeb: 3,
  );
}
