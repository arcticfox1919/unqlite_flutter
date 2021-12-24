import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:unqlite_flutter/unqlite.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  Future<void> initDatabase() async {
    var appDocDir = await getApplicationDocumentsDirectory();

    UnQLiteHelper helper = UnQLiteHelper("${appDocDir.path}/test.db");
    helper.store("name", "Alex");
    helper.store("age", "18");


    debugPrint(helper.fetch("name"));
    debugPrint(helper.fetch("age"));
    helper.close();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('UnQLite app'),
        ),
        body: Center(
          child: Text('Running on'),
        ),
      ),
    );
  }
}
