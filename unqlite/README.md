# unqlite_flutter

UnQLite database plugin wrapped for flutter.UnQLite is an embedded NoSql database, see [here](https://github.com/symisc/unqlite) for details.

Note that currently only the key-value store is wrapped.

Todo:

- [x]  key-value store
- [ ]  JSON document store

## Usage

Add dependencies：

```yaml
  unqlite: ^0.0.2
  unqlite_flutter: ^0.0.2
```

Simple key-value store:

```dart
// create or open a database
UnQLite db = UnQLite.open("${appDocDir.path}/test.db");

// save key-value pairs
db.store("name", "Alex");
db.store("age", 18);
db.store(19, "haha");

// get value by key
// but you have to specify the generic type of the value
debugPrint(db.fetch<String>("name"));
debugPrint('${db.fetch<int>("age")}');
debugPrint(db.fetch<String>(19));

// another way to get a value
db.fetchCallback<int>("age", (val) {
    debugPrint('age=$val');
});
```

Of course, there is another way to get the data, it might be faster than `fetch`：

```dart
var cursor = db.cursor();
cursor.seek('name');
debugPrint('=> ${cursor.key} => ${cursor.value}');
```

Also you can use transactions which is a great feature:

```dart
    var trans = db.transaction().begin();
    try {
      for (var i = 0; i < 100000; i++) {
        if (i == 10) {
          // Here, we generate an exception
          throw Exception('test');
        }
        db.store("transaction_$i", "here is a transaction_$i");
      }
      trans.commit();
    } catch (e) {
      // the transaction is rolled back here
      trans.rollback();
    }
```

You can also use iterators to iterate over all data:

```dart
for (var entry in db.cursor()) {
  var content = '${entry.key} => ${entry.value}';
  debugPrint(content);
}
```

## Why use it

- Faster than Hive and takes up less memory
- Can support JSON documents (not yet finished wrapping)

What are the drawbacks?  Because dart ffi is used, it cannot be used on the web.

Below is some performance test data, the percentage of memory is not listed here, but I'm sure unqlite only uses much less memory:

UnQLite:

```
UnQLite init:1 ms
write 100,000 entries :611 ms
fetch 100,000 entries :370 ms
seek  100,000 entries :215 ms
iterate 100,000 entries :225 ms
transaction rollback :39 ms
```

Hive:

```
Hive init:48 ms
put 100,000 entries :807 ms
get 100,000 entries :290 ms
```



Here is the code for testing, both running in profile mode on the same phone:

```dart
testUnQLite() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    final start = DateTime.now().millisecondsSinceEpoch;
    UnQLite db = UnQLite.open("${appDocDir.path}/test.db");
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

    debugPrint("UnQLite init:${t1-start} ms");
    debugPrint("write 100,000 entries :${t2-t1} ms");
    debugPrint("fetch 100,000 entries :${t3-t2} ms");
    debugPrint("seek  100,000 entries :${t4-t3} ms");
    debugPrint("iterate 100,000 entries :${t5-t4} ms");
    debugPrint("transaction rollback :${t6-t5} ms");
    db.close();
  }

  testHive() async {
    var appDocDir = await getApplicationDocumentsDirectory();
    var path = appDocDir.path;
    final start = DateTime.now().millisecondsSinceEpoch;
    Hive.init(path);
    var box = await Hive.openBox('testBox');

    final t1 = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < 100000; i++) {
      box.put("my_key_$i", "here is a transaction_$i");
    }

    final t2 = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < 100000; i++) {
      var name = box.get('my_key_$i');
    }

    final t3 = DateTime.now().millisecondsSinceEpoch;

    box.close();
    debugPrint("Hive init:${t1-start} ms");
    debugPrint("put 100,000 entries :${t2-t1} ms");
    debugPrint("get 100,000 entries :${t3-t2} ms");
  }
```

