import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unqlite/unqlite.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> testUnqlite() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    final start = DateTime.now().millisecondsSinceEpoch;

    UnQLite db = UnQLite.open("${appDocDir.path}/test1.db");
    db.store("name", "Alex");
    db.store("age", 18);
    db.store(19, "haha");

    debugPrint(db.fetch<String>("name"));
    debugPrint('${db.fetch<int>("age")}');
    debugPrint(db.fetch<String>(19));

    db.fetchCallback<int>("age", (val) {
      debugPrint('age=$val');
    });

    final t1 = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < 100000; i++) {
      db.store("my_key_$i", "Here is a value for testing—$i");
    }

    final t2 = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < 100000; i++) {
      var r = db.fetch<String>("my_key_$i");
      // debugPrint("fetch :$r");
    }

    final t3 = DateTime.now().millisecondsSinceEpoch;
    var cursor = db.cursor();
    for (var i = 0; i < 100000; i++) {
      cursor.seek('my_key_$i');
      // debugPrint('=> ${cursor.key} => ${cursor.value}');
    }
    final t4 = DateTime.now().millisecondsSinceEpoch;

    var count = 0;
    for (var entry in db.cursor()) {
      count++;
      var content = '${entry.key} => ${entry.value}';
      // debugPrint(content);
    }
    print('count => $count');
    final t5 = DateTime.now().millisecondsSinceEpoch;

    var trans = db.transaction().begin();
    try {
      for (var i = 0; i < 100000; i++) {
        if (i == 10) {
          throw Exception('test');
        }
        db.store("transaction_$i", "here is a transaction_$i");
      }
      trans.commit();
    } catch (e) {
      trans.rollback();
    }
    final t6 = DateTime.now().millisecondsSinceEpoch;

    debugPrint("database init:${t1-start} ms");
    debugPrint("write 100,000 entries :${t2-t1} ms");
    debugPrint("fetch 100,000 entries :${t3-t2} ms");
    debugPrint("seek  100,000 entries :${t4-t3} ms");
    debugPrint("iterate 100,000 entries :${t5-t4} ms");
    debugPrint("transaction rollback :${t6-t5} ms");

    db.close();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('UnQLite app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(onPressed: (){
                testUnqlite();
              }, child: Text('testUnqlite')),
              ElevatedButton(onPressed: (){
                testHive();
              }, child: Text('testHive')),
              ElevatedButton(onPressed: (){
                testJSON();
              }, child: Text('testJSON'))
            ],
          ),
        ),
      ),
    );
  }

  testHive() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    var path = appDocDir.path;
    final start = DateTime.now().millisecondsSinceEpoch;
    Hive.init(path);
    var box = await Hive.openBox('testBox');

    final n1 = DateTime.now().millisecondsSinceEpoch;
    final p1 = n1 - start;

    for (var i = 0; i < 100000; i++) {
      box.put("my_key_$i", "they're utterly stupid !");
    }

    final n2 = DateTime.now().millisecondsSinceEpoch;
    final p2 = n2 - n1;

    for (var i = 0; i < 100000; i++) {
      var name = box.get('my_key_$i');
    }

    final n3 = DateTime.now().millisecondsSinceEpoch;
    final p3 = n3 - n2;

    box.close();
    debugPrint("Hive init:$p1 ms");
    debugPrint("put :$p2 ms");
    debugPrint("get :$p3 ms");
  }

  testJSON()async{
    var appDocDir = await getApplicationDocumentsDirectory();
    final start = DateTime.now().millisecondsSinceEpoch;

    UnQLite db = UnQLite.open("${appDocDir.path}/test2.db");
    var users = db.collection("users");
    users.create();

    final t1 = DateTime.now().millisecondsSinceEpoch;

    users.store(jsonDecode('''
{
        "title": "test json string",
        "author": [
                "arcticfox1919"
        ],
        "year": 2022,
        "like": "flutter"
}
    '''));
    users.store({'name': 'Mickey', 'age': 17});
    users.store([
      {'name': 'Alice', 'age': 18},
      {'name': 'Bruce', 'age': 19},
      {'name': 'Charlie', 'age': 20},
    ]);
    final t2 = DateTime.now().millisecondsSinceEpoch;
    print('> ------------------------------------------------------- <');
    print(users.all());
    // print(users.fetch(0));
    // print(users.fetch(1));
    // print(users.fetch(2));
    // print(users.errorLog());
    final t3 = DateTime.now().millisecondsSinceEpoch;

    print(users.creationDate());
    print(users.len());
    print(users.fetchCurrent());
    users.drop();

    debugPrint("UnQLite collection init:${t1 - start} ms");
    debugPrint("UnQLite collection store:${t2 - t1} ms");
    debugPrint("UnQLite collection all:${t3 - t2} ms");
    db.close();
  }
}
