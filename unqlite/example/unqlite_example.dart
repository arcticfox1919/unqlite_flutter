import 'package:unqlite/unqlite.dart';

void main() {
  UnQLite unqlite = UnQLite.open("./test/test.db");
  unqlite.store("name", "Alex");
  unqlite.store("age", "18");
  print(unqlite.fetch("name"));
  print(unqlite.fetch("age"));

  unqlite.append("age", "19");
  unqlite.fetchCallback("age", (value) {
    print(value);
  });

//   unqlite.execute('''
// if( !db_exists('users') ){

//     /* Try to create it */

//    db_create('users');
// }

// \$zRec = [

// {
//    name : 'james',
//    age  : 27,
//    mail : 'dude@example.com'
// },

// {
//    name : 'robert',
//    age  : 35,
//    mail : 'rob@example.com'
// },

// {
//    name : 'monji',
//    age  : 47,
//    mail : 'monji@example.com'
// },
// {
//   name : 'barzini',
//   age  : 52,
//   mail : 'barz@mobster.com'
// }
// ];

// db_store('users',\$zRec);
//     ''');

  unqlite.close();
}
