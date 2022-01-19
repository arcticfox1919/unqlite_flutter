import 'dart:io';

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'unqlite_bindings.dart';

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

typedef FetchCallback = ffi.Int32 Function(
    ffi.Pointer, ffi.Uint32, ffi.Pointer);

typedef _WriteData = int Function(
  ffi.Pointer<unqlite>,
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<ffi.Void>,
  int,
);

class UnQLite {
  final ffi.DynamicLibrary _dylib;
  late UnQLiteBindings _unqlite;
  late ffi.Pointer<unqlite> _pdb;

  UnQLite(String dbName, [int flags = UNQLITE_OPEN_CREATE]) : _dylib = _load() {
    _unqlite = UnQLiteBindings(_dylib);
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Pointer<unqlite>> ppDB = calloc();

    var r = _unqlite.unqlite_open(ppDB, dbName.toNativeUtf8().cast(), flags);

    if (r != UNQLITE_OK) {
      throw Exception('Database open failed! The return value is $r');
    }
    _pdb = ppDB.value;
  }

  UnQLite.memory() : this(':mem:');

  bool store(String key, String value) {
    return _write(key, value, _unqlite.unqlite_kv_store);
  }

  bool append(String key, String value) {
    return _write(key, value, _unqlite.unqlite_kv_append);
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

  bool exists(String key) {
    var k = key.toNativeUtf8();
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Int64> pLen = calloc();
    int r;
    bool b = false;
    r = _unqlite.unqlite_kv_fetch(_pdb, k.cast(), -1, ffi.nullptr, pLen);
    if (r == UNQLITE_OK) {
      b = true;
    } else if (r == UNQLITE_NOTFOUND) {
      b = false;
    } else if (r == UNQLITE_IOERR) {
      throw Exception("Data fetch failed!");
    }
    return b;
  }

  void execute(String str) {
    ffi.Pointer<ffi.Pointer<unqlite_vm>> ppVM = calloc();
    var rc = _unqlite.unqlite_compile(
        _pdb, str.toNativeUtf8().cast(), str.length, ppVM);

    if (rc != UNQLITE_OK) {
      throw Exception("execute failed!");
    }

    // _unqlite.unqlite_vm_exec(pVm)
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