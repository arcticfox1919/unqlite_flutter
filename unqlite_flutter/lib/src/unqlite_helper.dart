import 'dart:io';


import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'unqlite_bindings.dart';


String _libPath= '';

set libPath(String path) => _libPath=path;

_load() {
  var path = _libPath.isNotEmpty ? _libPath : "libunqlite.so";

  if (Platform.isWindows) {
    path = _libPath.isNotEmpty ? _libPath : "libunqlite.dll";
  } else if (Platform.isMacOS) {
    path = _libPath.isNotEmpty ? _libPath : "libunqlite.dylib";
  }else if(Platform.isIOS){
    return ffi.DynamicLibrary.process();
  }

  return ffi.DynamicLibrary.open(path);
}

typedef FetchCallback = ffi.Int32 Function(
    ffi.Pointer, ffi.Uint32, ffi.Pointer);

typedef _WriteData = int Function(
  ffi.Pointer<unqlite>,
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<ffi.Void>,
  int,
);

class UnQLiteHelper {
  final ffi.DynamicLibrary _dylib;
  late UnQLite _unqlite;
  late ffi.Pointer<unqlite> _pdb;

  UnQLiteHelper(String dbName) : _dylib = _load() {
    _unqlite = UnQLite(_dylib);
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Pointer<unqlite>> ppDB = calloc();

    var r = _unqlite.unqlite_open(
        ppDB, dbName.toNativeUtf8().cast(), UNQLITE_OPEN_CREATE);

    if (r != UNQLITE_OK) {
      throw Exception('Database open failed! The return value is $r');
    }
    _pdb = ppDB.value;
  }

  UnQLiteHelper.memory() : this(':mem:');

  bool store(String k, String v) {
    return _write(k, v, _unqlite.unqlite_kv_store);
  }

  bool append(String k, String v) {
    return _write(k, v, _unqlite.unqlite_kv_append);
  }

  bool delete(String k) {
    var key = k.toNativeUtf8();
    int r;
    try {
      r = _unqlite.unqlite_kv_delete(_pdb, key.cast(), -1);
      // TODO:
      if (r != UNQLITE_OK) {
        if (r != UNQLITE_BUSY && r != UNQLITE_NOTFOUND) {
          /* Rollback */
          _unqlite.unqlite_rollback(_pdb);
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      calloc.free(key);
    }
    return r == UNQLITE_OK;
  }

  bool _write(String k, String v, _WriteData fn) {
    var key = k.toNativeUtf8();
    var val = v.toNativeUtf8();
    int r;
    try {
      r = fn.call(_pdb, key.cast(), -1, val.cast(), val.length);
    } catch (e) {
      rethrow;
    } finally {
      calloc.free(key);
      calloc.free(val);
    }
    return r == UNQLITE_OK;
  }

  String? fetch(String k) {
    var key = k.toNativeUtf8();
    ffi.Pointer<Utf8>? pVal;
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Int64> pLen = calloc();
    int r;
    try {
      r = _unqlite.unqlite_kv_fetch(_pdb, key.cast(), -1, ffi.nullptr, pLen);
      if (r == UNQLITE_OK) {
        var len = pLen.value;
        pVal = calloc<ffi.Uint8>(len).cast<Utf8>();
        r = _unqlite.unqlite_kv_fetch(_pdb, key.cast(), -1, pVal.cast(), pLen);
        if (r == UNQLITE_OK) {
          return pVal.toDartString(length: len);
        } else if (r == UNQLITE_IOERR) {
          throw Exception("Data fetch failed!");
        }
      } else if (r == UNQLITE_IOERR) {
        throw Exception("Data fetch failed!");
      }
      return null;
    } catch (e) {
      rethrow;
    } finally {
      calloc.free(key);
      calloc.free(pLen);
      if (pVal != null) calloc.free(pVal);
    }
  }

  void close() {
    _unqlite.unqlite_close(_pdb);
  }

  static int _callback(ffi.Pointer pData, int dataLen, ffi.Pointer pUserData) {
    var p = pData.cast<Utf8>();
    print(p.toDartString(length: dataLen));

    return UNQLITE_OK;
  }
}
