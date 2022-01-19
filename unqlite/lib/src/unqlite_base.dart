import 'dart:io';

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'unqlite_bindings.dart';

typedef FetchCallback = void Function(String value);

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

typedef _WriteData = int Function(
  ffi.Pointer<unqlite>,
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<ffi.Void>,
  int,
);

final Map<int, FetchCallback> _listener = {};

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

  bool delete(String key) {
    var k = key.toNativeUtf8();
    int r;
    try {
      r = _unqlite.unqlite_kv_delete(_pdb, k.cast(), -1);
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
      malloc.free(k);
    }
    return r == UNQLITE_OK;
  }

  bool exists(String key) {
    var k = key.toNativeUtf8();
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Int64> pLen = malloc();
    int r;
    bool b = false;

    try {
      r = _unqlite.unqlite_kv_fetch(_pdb, k.cast(), -1, ffi.nullptr, pLen);
      if (r == UNQLITE_OK) {
        b = true;
      } else if (r == UNQLITE_NOTFOUND) {
        b = false;
      } else if (r == UNQLITE_IOERR) {
        throw Exception("Data fetch failed!");
      }
    } catch (e) {
      rethrow;
    } finally {
      malloc.free(pLen);
    }
    return b;
  }

  void execute(String str) {
    ffi.Pointer<ffi.Pointer<unqlite_vm>> ppVM = malloc();

    try {
      var rc = _unqlite.unqlite_compile(
          _pdb, str.toNativeUtf8().cast(), str.length, ppVM);

      if (rc != UNQLITE_OK) {
        throw Exception("execute failed!");
      }
    } catch (e) {
      rethrow;
    } finally {
      malloc.free(ppVM);
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
      malloc.free(key);
      malloc.free(val);
    }
    return r == UNQLITE_OK;
  }

  String? fetch(String key) {
    var k = key.toNativeUtf8();
    ffi.Pointer<Utf8>? pVal;
    // ignore: omit_local_variable_types
    ffi.Pointer<ffi.Int64> pLen = malloc();
    int r;
    try {
      r = _unqlite.unqlite_kv_fetch(_pdb, k.cast(), -1, ffi.nullptr, pLen);
      if (r == UNQLITE_OK) {
        var len = pLen.value;
        pVal = malloc<ffi.Uint8>(len).cast<Utf8>();
        r = _unqlite.unqlite_kv_fetch(_pdb, k.cast(), -1, pVal.cast(), pLen);
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
      malloc.free(k);
      malloc.free(pLen);
      if (pVal != null) malloc.free(pVal);
    }
  }

  void fetchCallback(String key, FetchCallback callback) {
    _listener[callback.hashCode] = callback;
    ffi.Pointer<ffi.Uint64> hash = malloc();
    hash.value = callback.hashCode;

    var k = key.toNativeUtf8();
    int r = _unqlite.unqlite_kv_fetch_callback(_pdb, k.cast(), -1,
        ffi.Pointer.fromFunction(_callback, 0), hash.cast<ffi.Void>());

    if (r != UNQLITE_OK) {
      throw Exception("Data fetch failed! The return value is $r .");
    }
  }

  void close() {
    _unqlite.unqlite_close(_pdb);
  }

  static int _callback(ffi.Pointer<ffi.Void> pData, int dataLen,
      ffi.Pointer<ffi.Void> pUserData) {
    ffi.Pointer<ffi.Uint64> pHash = pUserData.cast();
    int hashCode = pHash.value;

    var pValue = pData.cast<Utf8>();
    if (_listener[hashCode] != null) {
      FetchCallback callback = _listener[hashCode]!;
      callback(pValue.toDartString(length: dataLen));
      _listener.remove(hashCode);
      malloc.free(pHash);
      return UNQLITE_OK;
    }
    malloc.free(pHash);
    return UNQLITE_ABORT;
  }
}
