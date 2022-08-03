
///
/// see: https://unqlite.org/jx9_builtin.html
///


const createCollection = '''
if (!db_exists(\$collection)) { 
\$ret = db_create(\$collection); 
} else { 
\$ret = false; 
}
''';


const dropCollection = '''
if (db_exists(\$collection)) {
\$ret = db_drop_collection(\$collection); 
}else { 
\$ret = false; 
}
''';


const storeCollection = '''
if (db_store(\$collection, \$record)) { 
\$ret = db_last_record_id(\$collection); 
}
''';