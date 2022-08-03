part of 'unqlite_base.dart';

typedef _WriteData = int Function(
  ffi.Pointer<unqlite>,
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<ffi.Void>,
  int,
);

enum _ResultType {
  bool,
  int,
  double,
  string,
}

class KVRecord {
  final Uint8List uint8Array;

  KVRecord(this.uint8Array);

  @override
  String toString() {
    return utf8.decode(uint8Array);
  }

  int toInt() {
    return ByteData.sublistView(uint8Array).getInt64(0);
  }

  double toDouble() {
    return ByteData.sublistView(uint8Array).getFloat64(0);
  }

  bool toBool() {
    return ByteData.sublistView(uint8Array).getInt8(0) == 1;
  }
}

class Transaction {
  final ffi.Pointer<unqlite> _pdb;

  Transaction._(this._pdb);

  Transaction begin() {
    _checkCallRet(_unqlite.unqlite_begin(_pdb), 'unqlite_begin');
    return this;
  }

  void commit() {
    _checkCallRet(_unqlite.unqlite_commit(_pdb), 'unqlite_commit');
  }

  void rollback() {
    _checkCallRet(_unqlite.unqlite_rollback(_pdb), 'unqlite_rollback');
  }
}

class Cursor with IterableMixin<CursorEntry> {
  final ffi.Pointer<unqlite> _pdb;
  late ffi.Pointer<unqlite_kv_cursor> _pCursor;

  Cursor._(this._pdb) {
    using((Arena arena) {
      var ppCursor = arena<ffi.Pointer<unqlite_kv_cursor>>();
      _checkCallRet(_unqlite.unqlite_kv_cursor_init(_pdb, ppCursor),
          'unqlite_kv_cursor_init');
      _pCursor = ppCursor.value;
    });
  }

  void reset() {
    _checkCallRet(
        _unqlite.unqlite_kv_cursor_reset(_pCursor), 'unqlite_kv_cursor_reset');
  }

  void seek(key) {
    using((arena) {
      var tuple = _checkKey(key, arena);
      _checkCallRet(
          _unqlite.unqlite_kv_cursor_seek(
              _pCursor, tuple.i1, tuple.i2, UNQLITE_CURSOR_MATCH_EXACT),
          'unqlite_kv_cursor_seek');
    });
  }

  void firstEntry() {
    var ret = _unqlite.unqlite_kv_cursor_first_entry(_pCursor);
    if (ret != UNQLITE_DONE) {
      _checkCallRet(ret, 'unqlite_kv_cursor_first_entry');
    }
  }

  void lastEntry() {
    var ret = _unqlite.unqlite_kv_cursor_last_entry(_pCursor);
    if (ret != UNQLITE_DONE) {
      _checkCallRet(ret, 'unqlite_kv_cursor_last_entry');
    }
  }

  void next() {
    var ret = _unqlite.unqlite_kv_cursor_next_entry(_pCursor);
    if (ret != UNQLITE_DONE) {
      _checkCallRet(ret, 'unqlite_kv_cursor_next_entry');
    }
  }

  void previous() {
    var ret = _unqlite.unqlite_kv_cursor_prev_entry(_pCursor);
    if (ret != UNQLITE_DONE) {
      _checkCallRet(ret, 'unqlite_kv_cursor_prev_entry');
    }
  }

  bool isValid() {
    return _unqlite.unqlite_kv_cursor_valid_entry(_pCursor) == 1;
  }

  void close() {
    _checkCallRet(_unqlite.unqlite_kv_cursor_release(_pdb, _pCursor),
        'unqlite_kv_cursor_release');
  }

  KVRecord get key {
    return using((arena) {
      var pLen = arena<ffi.Int>();
      _checkCallRet(_unqlite.unqlite_kv_cursor_key(_pCursor, ffi.nullptr, pLen),
          'unqlite_kv_cursor_key');
      var len = pLen.value;
      var pBuf = arena<ffi.Uint8>(len);
      _checkCallRet(_unqlite.unqlite_kv_cursor_key(_pCursor, pBuf.cast(), pLen),
          'unqlite_kv_cursor_key');
      return KVRecord(Uint8List.fromList(pBuf.asTypedList(len)));
    });
  }

  KVRecord get value {
    return using((arena) {
      var pLen = arena<ffi.LongLong>();
      _checkCallRet(
          _unqlite.unqlite_kv_cursor_data(_pCursor, ffi.nullptr, pLen),
          'unqlite_kv_cursor_data');
      var len = pLen.value;
      var pBuf = arena<ffi.Uint8>(len);
      _checkCallRet(
          _unqlite.unqlite_kv_cursor_data(_pCursor, pBuf.cast(), pLen),
          'unqlite_kv_cursor_data');
      return KVRecord(Uint8List.fromList(pBuf.asTypedList(len)));
    });
  }

  void delete() {
    _checkCallRet(_unqlite.unqlite_kv_cursor_delete_entry(_pCursor),
        'unqlite_kv_cursor_delete_entry');
  }

  @override
  Iterator<CursorEntry> get iterator => CursorIterator(this);
}

class Jx9VM {
  final ffi.Pointer<unqlite> _pdb;
  final String code;
  ffi.Pointer<unqlite_vm>? _pVm;
  final Arena _arena = Arena();

  Jx9VM(this._pdb, this.code);

  void compile() {
    using((arena) {
      var ppVm = arena<ffi.Pointer<unqlite_vm>>();
      var pCode = code.toNativeUtf8(allocator: arena);
      var len = pCode.length;
      _checkCallRet(_unqlite.unqlite_compile(_pdb, pCode.cast(), len, ppVm),
          'unqlite_compile');
      _pVm = ppVm.value;
    });
  }

  void execute() {
    if (_pVm != null && _pVm != ffi.nullptr) {
      _checkCallRet(_unqlite.unqlite_vm_exec(_pVm!), 'unqlite_vm_exec');
    } else {
      throw Exception('Jx9 script must be compiled before executing.');
    }
  }

  void reset() {
    if (_pVm != null && _pVm != ffi.nullptr) {
      _checkCallRet(_unqlite.unqlite_vm_reset(_pVm!), 'unqlite_vm_reset');
    } else {
      throw Exception('Jx9 script has not been compiled.');
    }
  }

  void close() {
    if (_pVm != null && _pVm != ffi.nullptr) {
      _checkCallRet(_unqlite.unqlite_vm_release(_pVm!), 'unqlite_vm_release');
    } else {
      throw Exception('Jx9 script has not been compiled.');
    }
    _arena.releaseAll();
  }

  ///
  /// Set the value of a variable in the Jx9 script.
  ///
  void setValue(String name, dynamic value) {
    if (_pVm != null && _pVm != ffi.nullptr) {
      using((arena) {
        var ptr = _createValue(value, arena);
        /*
         * since Jx9 does not make a private copy of the `name`,
         * we need to keep it alive by `_arena`
         */
        _checkCallRet(
            _unqlite.unqlite_vm_config(_pVm!, UNQLITE_VM_CONFIG_CREATE_VAR,
                name.toNativeUtf8(allocator: _arena).cast(), ptr),
            'unqlite_vm_config');

        _releaseValue(ptr);
      });
    } else {
      throw Exception('Jx9 script has not been compiled.');
    }
  }

  ///
  /// Retrieve the value of a variable after the execution of the Jx9 script.
  ///
  dynamic getValue(String name) {
    if (_pVm != null && _pVm != ffi.nullptr) {
      return using((arena) {
        var ptr = _unqlite.unqlite_vm_extract_variable(
            _pVm!, name.toNativeUtf8(allocator: arena).cast());
        if (ptr == ffi.nullptr) {
          throw UnQLiteKeyError(name);
        }

        try {
          return _toDartType(ptr);
        } finally {
          _releaseValue(ptr);
        }
      });
    } else {
      throw Exception('Jx9 script has not been compiled.');
    }
  }

  void setValues(Map data) {
    for (var item in data.entries) {
      setValue(item.key, item.value);
    }
  }

  ffi.Pointer<unqlite_value> _createArray() {
    return _unqlite.unqlite_vm_new_array(_pVm!);
  }

  ffi.Pointer<unqlite_value> _createScalar() {
    return _unqlite.unqlite_vm_new_scalar(_pVm!);
  }

  ffi.Pointer<unqlite_value> _createValue(value, Arena arena) {
    ffi.Pointer<unqlite_value> ptr;
    if (value is List || value is Map) {
      ptr = _createArray();
    } else {
      ptr = _createScalar();
    }
    _toUnqliteValue(ptr, value, arena);
    return ptr;
  }

  void _releaseValue(ffi.Pointer<unqlite_value> ptr) {
    _checkCallRet(_unqlite.unqlite_vm_release_value(_pVm!, ptr),
        'unqlite_vm_release_value');
  }

  void _toUnqliteValue(
      ffi.Pointer<unqlite_value> ptr, dynamic val, Arena arena) {
    if (val is bool) {
      _unqlite.unqlite_value_bool(ptr, val ? 1 : 0);
    } else if (val is int) {
      _unqlite.unqlite_value_int64(ptr, val);
    } else if (val is double) {
      _unqlite.unqlite_value_double(ptr, val);
    } else if (val is String) {
      _unqlite.unqlite_value_string(
          ptr, val.toNativeUtf8(allocator: arena).cast(), val.length);
    } else if (val is List) {
      for (var item in val) {
        var p = _createValue(item, arena);
        _unqlite.unqlite_array_add_elem(ptr, ffi.nullptr, p);
        _releaseValue(p);
      }
    } else if (val is Map<String, dynamic>) {
      for (var entry in val.entries) {
        var k = entry.key.toNativeUtf8(allocator: arena);
        var itemPtr = _createValue(entry.value, arena);
        _unqlite.unqlite_array_add_strkey_elem(ptr, k.cast(), itemPtr);
        _releaseValue(itemPtr);
      }
    } else {
      _unqlite.unqlite_value_null(ptr);
    }
  }
}

bool _bool(int i) {
  return i == 1;
}

dynamic _toDartType(ffi.Pointer<unqlite_value> ptr) {
  if (_bool(_unqlite.unqlite_value_is_json_object(ptr))) {
    var timestamp = DateTime.now().microsecondsSinceEpoch;
    _registry[timestamp] = {};
    var pTime = malloc<ffi.Uint64>();
    pTime.value = timestamp;
    _unqlite.unqlite_array_walk(
        ptr, ffi.Pointer.fromFunction(unqliteValueToMap, 404), pTime.cast());
    malloc.free(pTime);
    return _registry.remove(timestamp);
  } else if (_bool(_unqlite.unqlite_value_is_json_array(ptr))) {
    var timestamp = DateTime.now().microsecondsSinceEpoch;
    _registry[timestamp] = [];
    var pTime = malloc<ffi.Uint64>();
    pTime.value = timestamp;
    _unqlite.unqlite_array_walk(
        ptr, ffi.Pointer.fromFunction(unqliteValueToList, 404), pTime.cast());
    malloc.free(pTime);
    return _registry.remove(timestamp);
  } else if (_bool(_unqlite.unqlite_value_is_string(ptr))) {
    var strPtr = _unqlite.unqlite_value_to_string(ptr, ffi.nullptr);
    return strPtr.cast<Utf8>().toDartString();
  } else if (_bool(_unqlite.unqlite_value_is_int(ptr))) {
    return _unqlite.unqlite_value_to_int64(ptr);
  } else if (_bool(_unqlite.unqlite_value_is_float(ptr))) {
    return _unqlite.unqlite_value_to_double(ptr);
  } else if (_bool(_unqlite.unqlite_value_is_bool(ptr))) {
    return _bool(_unqlite.unqlite_value_to_bool(ptr));
  } else if (_bool(_unqlite.unqlite_value_is_null(ptr))) {
    return null;
  } else {
    throw TypeError();
  }
}

var _registry = {};

int unqliteValueToList(ffi.Pointer<unqlite_value> key,
    ffi.Pointer<unqlite_value> val, ffi.Pointer<ffi.Void> pData) {
  ffi.Pointer<ffi.Uint64> pTime = pData.cast();
  var timestamp = pTime.value;
  var jsonArr = _registry[timestamp] as List;

  jsonArr.add(_toDartType(val));
  return UNQLITE_OK;
}

int unqliteValueToMap(ffi.Pointer<unqlite_value> key,
    ffi.Pointer<unqlite_value> val, ffi.Pointer<ffi.Void> pData) {
  ffi.Pointer<ffi.Uint64> pTime = pData.cast();
  var timestamp = pTime.value;
  var jsonObj = _registry[timestamp] as Map;

  var k = _toDartType(key);
  jsonObj[k] = _toDartType(val);
  return UNQLITE_OK;
}

///
/// Manage collections of UnQLite JSON documents.
///
class Collection {
  final ffi.Pointer<unqlite> _pdb;
  final String name;

  Collection(this._pdb, this.name);

  void _execute(String script, {Map? data}) {
    var vm = Jx9VM(_pdb, script);
    try {
      vm.compile();
      vm.setValue('collection', name);
      if (data != null) vm.setValues(data);
      vm.execute();
    } finally {
      vm.close();
    }
  }

  _simpleExecute(String script, {Map? data}) {
    var vm = Jx9VM(_pdb, script);
    try {
      vm.compile();
      vm.setValue('collection', name);
      if (data != null) vm.setValues(data);
      vm.execute();
      return vm.getValue('ret');
    } finally {
      vm.close();
    }
  }

  ///
  ///  Create the named collection.
  ///         Note: this does not create a new JSON document, this method is
  ///        used to create the collection itself.
  ///
  bool create() {
    return _simpleExecute(createCollection);
  }

  ///
  /// Drop the collection and all associated records.
  ///
  bool drop() {
    return _simpleExecute(dropCollection);
  }

  ///
  /// Return boolean indicating whether the collection exists.
  ///
  bool exists() {
    return _simpleExecute('\$ret = db_exists(\$collection);');
  }

  ///
  /// Return the ID of the last document to be stored.
  ///
  int lastRecordId() {
    return _simpleExecute('\$ret = db_last_record_id(\$collection);');
  }

  ///
  /// Return the ID of the current JSON document.
  ///
  int currentRecordId() {
    return _simpleExecute('\$ret = db_current_record_id(\$collection);');
  }

  ///
  /// Retrieve all records in the given collection.
  ///
  List? all() {
    return _simpleExecute('\$ret = db_fetch_all(\$collection);');
  }

  ///
  ///  reset the internal record cursor so that a call to db_fetch() can re-start from the beginning.
  ///
  void resetCursor() {
    _execute('db_reset_record_cursor(\$collection);');
  }

  ///
  /// return the creation date of the given collection.
  ///
  String creationDate() {
    return _simpleExecute('\$ret = db_creation_date(\$collection);');
  }

  bool setSchema([Map? schema, Map? data]) {
    schema ??= {};
    if (data != null) {
      schema.updateAll((k, v) {
        if (data.containsKey(k)) {
          return data[k];
        }
        return v;
      });
    }
    return _simpleExecute('\$ret = db_set_schema(\$collection, \$schema);',
        data: {'schema': schema});
  }

  Map? getSchema() {
    return _simpleExecute('\$ret = db_get_schema(\$collection);');
  }

  ///
  /// Return the number of records in the document collection.
  ///
  int len() {
    return _simpleExecute('\$ret = db_total_records(\$collection);');
  }

  ///
  /// Delete the document associated with the given ID.
  ///
  bool delete(int recordId) {
    var script = '\$ret = db_drop_record(\$collection, \$record_id);';
    return _simpleExecute(script, data: {'record_id': recordId});
  }

  ///
  /// Fetch the document associated with the given ID.
  ///
  fetch(int recordId) {
    var script = '\$ret = db_fetch_by_id(\$collection, \$record_id);';
    return _simpleExecute(script, data: {'record_id': recordId});
  }

  ///
  /// Create a new JSON document in the collection, optionally returning
  ///         the new record's ID.
  /// [returnId] is true then return int, otherwise return bool
  ///
  store(dynamic record, [returnId = false]) {
    var script = returnId
        ? storeCollection
        : '\$ret = db_store(\$collection, \$record);';
    return _simpleExecute(script, data: {'record': record});
  }

  ///
  /// Update the record identified by the given ID.
  ///
  update(int recordId, record) {
    var script =
        '\$ret = db_update_record(\$collection, \$record_id, \$record);';
    return _simpleExecute(script,
        data: {'record': record, 'record_id': recordId});
  }

  ///
  /// Fetch the current record from the target collection
  /// and automatically advance the cursor to the next record in the collection.
  ///
  fetchCurrent() {
    return _simpleExecute('\$ret = db_fetch(\$collection);');
  }

  ///
  /// return the database error log. The database error log is stored in an internal buffer.
  /// When something goes wrong during a db_store(), db_create(), db_fetch(), etc.,
  /// a human-readable error message is generated to help clients diagnostic the problem.
  ///
  String errorLog() {
    return _simpleExecute('\$ret = db_errlog();');
  }
}

Tuple2<ffi.Pointer<ffi.Void>, int> _checkKey(key, Arena arena) {
  ByteData? kData;
  if (key is int) {
    kData = ByteData(8);
    kData.setInt64(0, key);
  } else if (key is double) {
    kData = ByteData(8);
    kData.setFloat64(0, key);
  } else if (key is String) {
  } else {
    throw Exception('This key is of an unsupported type!!!');
  }

  ffi.Pointer<ffi.Void> pKey;
  int kLen = -1;
  if (kData != null) {
    kLen = kData.lengthInBytes;
    var p = arena<ffi.Uint8>(kLen);
    final Uint8List nativeArr = p.asTypedList(kLen);
    nativeArr.setAll(0, kData.buffer.asUint8List());
    pKey = p.cast();
  } else {
    var p = (key as String).toNativeUtf8(allocator: arena);
    kLen = p.length;
    pKey = p.cast();
  }
  return Tuple2<ffi.Pointer<ffi.Void>, int>(pKey, kLen);
}

Tuple2<ffi.Pointer<ffi.Void>, int> _checkValue(val, Arena arena) {
  ByteData? vData;
  if (val is int) {
    vData = ByteData(8);
    vData.setInt64(0, val);
  } else if (val is double) {
    vData = ByteData(8);
    vData.setFloat64(0, val);
  } else if (val is bool) {
    vData = ByteData(1);
    vData.setInt8(0, val ? 1 : 0);
  } else if (val is String) {
  } else {
    throw Exception('This value is of an unsupported type!!!');
  }

  ffi.Pointer<ffi.Void> pVal;
  int vLen = -1;
  if (vData != null) {
    vLen = vData.lengthInBytes;
    var p = arena<ffi.Uint8>(vLen);
    final Uint8List nativeArr = p.asTypedList(vLen);
    nativeArr.setAll(0, vData.buffer.asUint8List());
    pVal = p.cast();
  } else {
    var p = (val as String).toNativeUtf8(allocator: arena);
    vLen = p.length;
    pVal = p.cast();
  }
  return Tuple2<ffi.Pointer<ffi.Void>, int>(pVal, vLen);
}

_ResultType _checkResult<R>() {
  if (R == bool) {
    return _ResultType.bool;
  } else if (R == int) {
    return _ResultType.int;
  } else if (R == double) {
    return _ResultType.double;
  } else if (R == String) {
    return _ResultType.string;
  } else {
    throw Exception('Result type is not supported!!!');
  }
}

int _checkCallRet(int ret, String funcName) {
  if (ret == UNQLITE_NOTFOUND) return ret;

  if (ret != UNQLITE_OK) {
    throw UnQLiteError(
        ret, 'An error occurred when calling the `$funcName` !!!');
  }
  return ret;
}

class UnQLiteKeyError extends Error {
  final String key;

  UnQLiteKeyError([this.key = '']);

  @override
  String toString() {
    return 'The $key key you retrieved does not exist!';
  }
}

class UnQLiteError extends Error {
  final String message;
  final int ret;

  UnQLiteError(this.ret, [this.message = '']);

  @override
  String toString() {
    var reason = _wrongReason[ret];
    var wrongReason = reason == null
        ? "the return value is $ret ."
        : "Possible reasons for this error:: $reason";
    return message.isNotEmpty
        ? "$message $wrongReason"
        : "UnQLite reported an error ，$wrongReason";
  }
}

class Tuple2<T1, T2> {
  final T1 i1;
  final T2 i2;

  const Tuple2(this.i1, this.i2);
}

const _wrongReason = {
  UNQLITE_BUSY:
      'Another thread or process have a reserved or exclusive lock on the database.',
  UNQLITE_READ_ONLY: 'Read-only Key/Value storage engine.',
  UNQLITE_NOTIMPLEMENTED:
      'The underlying KV storage engine does not implement the xReplace() method.',
  UNQLITE_PERM: 'Permission error.',
  UNQLITE_LIMIT: 'Journal file record limit reached (An unlikely scenario).',
  UNQLITE_IOERR: 'OS specific error.',
  UNQLITE_NOMEM: 'Out of memory.',
};
