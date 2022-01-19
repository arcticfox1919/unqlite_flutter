import 'package:flutter/material.dart';
import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    initDatabase();
  }

  Future<void> initDatabase() async {
    var appDocDir = await getApplicationDocumentsDirectory();

    UnQLite helper = UnQLite("${appDocDir.path}/test.db");
    helper.store("name", "Alex");
    helper.store("age", "18");


    debugPrint(helper.fetch("name"));
    debugPrint(helper.fetch("age"));
    helper.execute('''
if( !db_exists('users') ){

    /* Try to create it */

   db_create('users');
}

\$zRec = [

{
   name : 'james',
   age  : 27,
   mail : 'dude@example.com'
},

{
   name : 'robert',
   age  : 35,
   mail : 'rob@example.com'
},

{
   name : 'monji',
   age  : 47,
   mail : 'monji@example.com'
},
{
  name : 'barzini',
  age  : 52,
  mail : 'barz@mobster.com'
}
];

db_store('users',\$zRec);
    ''');

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
