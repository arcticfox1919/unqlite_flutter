
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'unqlite_bindings.dart';
part 'internal.dart';
part 'cursor_iterator.dart';

typedef FetchCallback = void Function(dynamic);

String _libPath = '';

set libPath(String path) => _libPath = path;

ffi.DynamicLibrary _load() {
  var path = _libPath.isNotEmpty ? _libPath : "libunqlite.so";

  if (Platform.isWindows) {
    path = _libPath.isNotEmpty ? _libPath : "libunqlite.dll";
  } else if (Platform.isMacOS) {
    path = _libPath.isNotEmpty ? _libPath : "libunqlite.dylib";
  } else if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  }

  return ffi.DynamicLibrary.open(path);
}

class UnQLite {
  final ffi.DynamicLibrary _dylib;
  late UnQLiteBindings _unqlite;
  late ffi.Pointer<unqlite> _pdb;
  bool _isOpen = false;

  UnQLite.lazy():_dylib = _load();

  UnQLite.memory() : this.open(':mem:');

  UnQLite.open(String filename, [int flags = UNQLITE_OPEN_CREATE]):_dylib = _load(){
    open(filename,flags);
  }

  void open(String filename, [int flags = UNQLITE_OPEN_CREATE]){
    if(!_isOpen){
      _unqlite = UnQLiteBindings(_dylib);
      using((Arena arena) {
        var ppDB = arena<ffi.Pointer<unqlite>>();
        _checkCallRet(_unqlite.unqlite_open(ppDB, filename.toNativeUtf8(allocator: arena).cast(), flags), 'unqlite_open');
        _pdb = ppDB.value;
      });
      _isOpen = true;
    }
  }

  void store(key, value) {
    var r = _write(key, value, _unqlite.unqlite_kv_store);
    if (r != UNQLITE_OK) {
      throw Exception("Store failed! The return value is $r .");
    }
  }

  void append(key, String value) {
    var r = _write(key, value, _unqlite.unqlite_kv_append);
    if (r != UNQLITE_OK) {
      throw Exception("Append failed! The return value is $r .");
    }
  }

  bool delete(key) {
    return using((arena) {
      var tuple = _checkKey(key, arena);
      var r = _unqlite.unqlite_kv_delete(_pdb, tuple.i1, tuple.i2);
      if (r != UNQLITE_OK) {
        if (r != UNQLITE_BUSY && r != UNQLITE_NOTFOUND) {
          /* Rollback */
          _unqlite.unqlite_rollback(_pdb);
        }
        return false;
      } else {
        return true;
      }
    });
  }

  bool exists(key) {
    return using((arena) {
      var tuple = _checkKey(key, arena);
      var pLen = arena<ffi.Int64>();
      var r = _unqlite.unqlite_kv_fetch(_pdb, tuple.i1, tuple.i2, ffi.nullptr, pLen);
      if (r == UNQLITE_OK) {
        return true;
      } else if (r == UNQLITE_NOTFOUND) {
        return false;
      } else if (r == UNQLITE_IOERR) {
        throw Exception("call exists: fetch data failed!!!");
      } else {
        throw Exception("call exists: unknown error! The return value is $r .");
      }
    });
  }

  int _write(key, val, _WriteData fn) {
    return using((Arena arena) {
      var kTuple = _checkKey(key, arena);
      var vTuple = _checkValue(val, arena);
      return fn.call(_pdb, kTuple.i1, kTuple.i2, vTuple.i1, vTuple.i2);
    });
  }

  String? _getLastError(){
    return using((arena){
      var pLen = arena<ffi.Int32>();
      var ppBuf = arena<ffi.Pointer<ffi.Uint8>>();
      var ret = _unqlite.unqlite_config(_pdb,UNQLITE_CONFIG_ERR_LOG,ppBuf,pLen);
      var size = pLen.value;
      if(ret != UNQLITE_OK || size == 0){
        return null;
      }

      var pBuf = ppBuf.value as ffi.Pointer<Utf8>;
      return pBuf.toDartString(length: size);
    });
  }

  Collection collection() {
    return Collection();
  }

  Transaction transaction() {
    return Transaction._(_pdb, _unqlite);
  }

  Cursor cursor() {
    return Cursor._(_pdb, _unqlite);
  }

  R? fetch<R>(key) {
    return using((Arena arena) {
      var tuple = _checkKey(key, arena);
      var pLen = arena<ffi.Int64>();
      int r = _checkCallRet(_unqlite.unqlite_kv_fetch(_pdb, tuple.i1, tuple.i2, ffi.nullptr, pLen), 'unqlite_kv_fetch');
      if(r == UNQLITE_NOTFOUND) return null;
      var len = pLen.value;
      var pVal = arena<ffi.Uint8>(len);
      _checkCallRet(_unqlite.unqlite_kv_fetch(_pdb, tuple.i1, tuple.i2, pVal.cast(), pLen), 'unqlite_kv_fetch');
      return _convertBy<R>(pVal, len);
    });
  }

  void fetchCallback<R>(key, FetchCallback callback) {
    using((Arena arena) {
      var tuple = _checkKey(key, arena);
      var timestamp = DateTime.now().microsecondsSinceEpoch;
      _listener[timestamp] = callback;
      var pParam = arena<_CallbackParam>();
      pParam.ref.type = _checkResult<R>().index;
      pParam.ref.timestamp = timestamp;
      _checkCallRet(_unqlite.unqlite_kv_fetch_callback(_pdb, tuple.i1, tuple.i2, ffi.Pointer.fromFunction(_callback, 404), pParam.cast()), 'unqlite_kv_fetch_callback');
    });
  }

  get isOpen => _isOpen;

  void close() {
    if(_isOpen){
      _unqlite.unqlite_close(_pdb);
      _isOpen = false;
    }
  }

  static int _callback(ffi.Pointer<ffi.Void> pData, int dataLen, ffi.Pointer<ffi.Void> pUserData) {
    ffi.Pointer<_CallbackParam> pParam = pUserData.cast();
    int timestamp = pParam.ref.timestamp;
    if (_listener[timestamp] != null) {
      var pValue = pData.cast<ffi.Uint8>();
      FetchCallback callback = _listener.remove(timestamp)!;
      Object r;
      var t = _ResultType.values[pParam.ref.type];
      switch (t) {
        case _ResultType.bool:
          r = _convertBy<bool>(pValue, dataLen);
          break;
        case _ResultType.int:
          r = _convertBy<int>(pValue, dataLen);
          break;
        case _ResultType.double:
          r = _convertBy<double>(pValue, dataLen);
          break;
        case _ResultType.string:
          r = _convertBy<String>(pValue, dataLen);
          break;
        default:
          throw Exception('Result type is not supported!!!');
      }
      callback(r);
      return UNQLITE_OK;
    }
    return UNQLITE_ABORT;
  }
}

final Map<int, FetchCallback> _listener = {};

R _convertBy<R>(ffi.Pointer<ffi.Uint8> val, int length) {
  RangeError.checkNotNegative(length, 'length');
  var byteArr = val.asTypedList(length);
  ByteData bd = ByteData.sublistView(byteArr);
  if (R == bool) {
    return (bd.getInt8(0) == 1) as R;
  } else if (R == int) {
    return bd.getInt64(0) as R;
  } else if (R == double) {
    return bd.getFloat64(0) as R;
  } else if (R == String) {
    return utf8.decode(byteArr) as R;
  } else{
    throw Exception('Unsupported conversion type: $R !!!');
  }
}

class _CallbackParam extends ffi.Struct {
  @ffi.Int8()
  external int type;
  @ffi.Uint64()
  external int timestamp;
}
