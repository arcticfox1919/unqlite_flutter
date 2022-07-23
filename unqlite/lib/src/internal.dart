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

class KVRecord{
  final Uint8List uint8Array;

  KVRecord(this.uint8Array);

  @override
  String toString() {
    return utf8.decode(uint8Array);
  }

  int toInt(){
    return ByteData.sublistView(uint8Array).getInt64(0);
  }

  double toDouble(){
    return ByteData.sublistView(uint8Array).getFloat64(0);
  }

  bool toBool(){
    return ByteData.sublistView(uint8Array).getInt8(0) == 1;
  }
}

class Transaction{
  final ffi.Pointer<unqlite> _pdb;
  final UnQLiteBindings _unqlite;

  Transaction._(this._pdb,this._unqlite);

  Transaction begin(){
    _checkCallRet(_unqlite.unqlite_begin(_pdb),'unqlite_begin');
    return this;
  }

  void commit(){
    _checkCallRet(_unqlite.unqlite_commit(_pdb),'unqlite_commit');
  }

  void rollback(){
    _checkCallRet(_unqlite.unqlite_rollback(_pdb),'unqlite_rollback');
  }
}

class Cursor with IterableMixin<CursorEntry>{
  final ffi.Pointer<unqlite> _pdb;
  final UnQLiteBindings _unqlite;
  late ffi.Pointer<unqlite_kv_cursor> _pCursor;

  Cursor._(this._pdb,this._unqlite){
    using((Arena arena){
      var ppCursor = arena<ffi.Pointer<unqlite_kv_cursor>>();
      _checkCallRet(_unqlite.unqlite_kv_cursor_init(_pdb,ppCursor), 'unqlite_kv_cursor_init');
      _pCursor = ppCursor.value;
    });
  }


  void reset(){
    _checkCallRet(_unqlite.unqlite_kv_cursor_reset(_pCursor), 'unqlite_kv_cursor_reset');
  }

  void seek(key){
    using((arena){
      var tuple = _checkKey(key, arena);
      _checkCallRet(_unqlite.unqlite_kv_cursor_seek(_pCursor,tuple.i1,tuple.i2,UNQLITE_CURSOR_MATCH_EXACT), 'unqlite_kv_cursor_seek');
    });
  }

  void firstEntry(){
    var ret = _unqlite.unqlite_kv_cursor_first_entry(_pCursor);
    if(ret != UNQLITE_DONE){
      _checkCallRet(ret, 'unqlite_kv_cursor_first_entry');
    }
  }

  void lastEntry(){
    var ret = _unqlite.unqlite_kv_cursor_last_entry(_pCursor);
    if(ret != UNQLITE_DONE){
      _checkCallRet(ret, 'unqlite_kv_cursor_last_entry');
    }
  }

  void next(){
    var ret = _unqlite.unqlite_kv_cursor_next_entry(_pCursor);
    if(ret != UNQLITE_DONE){
      _checkCallRet(ret, 'unqlite_kv_cursor_next_entry');
    }
  }

  void previous(){
    var ret = _unqlite.unqlite_kv_cursor_prev_entry(_pCursor);
    if(ret != UNQLITE_DONE){
      _checkCallRet(ret, 'unqlite_kv_cursor_prev_entry');
    }
  }

  bool isValid(){
    return _unqlite.unqlite_kv_cursor_valid_entry(_pCursor) == 1;
  }

  void close(){
    _checkCallRet(_unqlite.unqlite_kv_cursor_release(_pdb,_pCursor), 'unqlite_kv_cursor_release');
  }

  KVRecord get key{
    return using((arena){
      var pLen = arena<ffi.Int32>();
      _checkCallRet(_unqlite.unqlite_kv_cursor_key(_pCursor,ffi.nullptr,pLen), 'unqlite_kv_cursor_key');
      var len = pLen.value;
      var pBuf = arena<ffi.Uint8>(len);
      _checkCallRet(_unqlite.unqlite_kv_cursor_key(_pCursor,pBuf.cast(),pLen), 'unqlite_kv_cursor_key');
      return KVRecord(Uint8List.fromList(pBuf.asTypedList(len)));
    });
  }

  KVRecord get value{
    return using((arena){
      var pLen = arena<ffi.Int64>();
      _checkCallRet(_unqlite.unqlite_kv_cursor_data(_pCursor,ffi.nullptr,pLen), 'unqlite_kv_cursor_data');
      var len = pLen.value;
      var pBuf = arena<ffi.Uint8>(len);
      _checkCallRet(_unqlite.unqlite_kv_cursor_data(_pCursor,pBuf.cast(),pLen), 'unqlite_kv_cursor_data');
      return KVRecord(Uint8List.fromList(pBuf.asTypedList(len)));
    });
  }

  void delete(){
    _checkCallRet(_unqlite.unqlite_kv_cursor_delete_entry(_pCursor), 'unqlite_kv_cursor_delete_entry');
  }

  @override
  Iterator<CursorEntry> get iterator => CursorIterator(this);
}

class Jx9VM{

  final ffi.Pointer<unqlite> _pdb;
  final UnQLiteBindings _unqlite;
  final String code;
  ffi.Pointer<unqlite_vm>? _pVm;

  Jx9VM(this._pdb,this._unqlite,this.code);

  void compile(){
    using((arena){
      var ppVm = arena<ffi.Pointer<unqlite_vm>>();
      var pCode = code.toNativeUtf8(allocator: arena);
      var len = pCode.length;
      _checkCallRet(_unqlite.unqlite_compile(_pdb,pCode.cast(),len,ppVm), 'unqlite_compile');
      _pVm = ppVm.value;
    });
  }

  void execute(){
    if(_pVm != null && _pVm != ffi.nullptr){
      _checkCallRet(_unqlite.unqlite_vm_exec(_pVm!), 'unqlite_vm_exec');
    }else{
      throw Exception('Jx9 script must be compiled before executing.');
    }
  }

  void reset(){
    if(_pVm != null && _pVm != ffi.nullptr){
      _checkCallRet(_unqlite.unqlite_vm_reset(_pVm!), 'unqlite_vm_reset');
    }else{
      throw Exception('Jx9 script has not been compiled.');
    }
  }

  void close() {
    if (_pVm != null && _pVm != ffi.nullptr) {
      _checkCallRet(_unqlite.unqlite_vm_release(_pVm!), 'unqlite_vm_release');
    }
  }
}

class Collection{

}

Tuple2<ffi.Pointer<ffi.Void>,int> _checkKey(key,Arena arena) {
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
  return Tuple2<ffi.Pointer<ffi.Void>,int>(pKey, kLen);
}

Tuple2<ffi.Pointer<ffi.Void>,int> _checkValue(val,Arena arena) {
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
  return Tuple2<ffi.Pointer<ffi.Void>,int>(pVal, vLen);
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

int _checkCallRet(int ret,String funcName){
  if(ret == UNQLITE_NOTFOUND) return ret;

  if(ret != UNQLITE_OK){
    throw UnQLiteError(ret,'An error occurred when calling the `$funcName` !!!');
  }
  return ret;
}

class UnQLiteError extends Error{
  final String message;
  final int ret;

  UnQLiteError(this.ret,[this.message='']);

  @override
  String toString() {
      var reason = _wrongReason[ret];
      var wrongReason = reason == null ? "the return value is $ret .":"Possible reasons for this error:: $reason";
      return message.isNotEmpty ? "$message $wrongReason":"UnQLite reported an error ，$wrongReason";
  }
}

class Tuple2<T1, T2> {
  final T1 i1;
  final T2 i2;

  const Tuple2(this.i1,this.i2);
}

const _wrongReason = {
  UNQLITE_BUSY:'Another thread or process have a reserved or exclusive lock on the database.',
  UNQLITE_READ_ONLY:'Read-only Key/Value storage engine.',
  UNQLITE_NOTIMPLEMENTED:'The underlying KV storage engine does not implement the xReplace() method.',
  UNQLITE_PERM:'Permission error.',
  UNQLITE_LIMIT:'Journal file record limit reached (An unlikely scenario).',
  UNQLITE_IOERR:'OS specific error.',
  UNQLITE_NOMEM:'Out of memory.',
};
