part of 'unqlite_base.dart';


class CursorEntry{
  KVRecord key;
  KVRecord value;

  CursorEntry(this.key,this.value);
}

class CursorIterator extends Iterator<CursorEntry>{

  final Cursor _cursor;
  bool _hasMoveFirst = false;

  CursorIterator(this._cursor);

  @override
  get current => CursorEntry(_cursor.key, _cursor.value);

  @override
  bool moveNext() {
    if(!_hasMoveFirst) {
      _cursor.firstEntry();
      _hasMoveFirst = true;
    }else{
      _cursor.next();
    }
    return _cursor.isValid();
  }
}