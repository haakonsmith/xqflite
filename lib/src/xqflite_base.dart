import 'dart:async';
import 'dart:io';

import 'package:xqflite/src/batch.dart';
import 'package:xqflite/src/column.dart';
// import 'package:sqflite/sqflite.dart' as sql;
// import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqfliteFfi;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:xqflite/xqflite.dart';

typedef Migration = Future<void> Function(XqfliteDatabase db, int version);

class XqfliteSqlBuilder extends StatementBuilder {
  final XqfliteDatabase database;

  XqfliteSqlBuilder(this.database);

  Future<void> execute() async {
    await database.execute(toSql());
  }
}

abstract interface class QueryExecutor {
  Future<int> update(Table table, Map<String, Object?> values, Query query);
  Future<int> delete(Table table, Query query);
  Future<int> insert(Table table, Map<String, Object?> values);

  Future<List<Map<String, Object?>>> query(Table table, Query query);
  Stream<List<Map<String, Object?>>> watchQuery(Table table, Query query);

  Future<void> batch(void Function(Batch batch) executor);
}

class XqfliteDatabase implements QueryExecutor {
  static const metaTableName = '__META_TABLE__';

  DbTable get metaTable => tables[metaTableName]!;

  Completer<void>? _initialisationCompleter;
  bool get initialised => _initialisationCompleter?.isCompleted ?? false;

  Future<void>? get future => _initialisationCompleter?.future;

  sql.Database? _db;
  final StreamController<Table> _tableUpdates = StreamController.broadcast();
  late Schema schema;
  late Map<String, DbTable> tables;
  late List<Migration> migrations;

  Future<void> open(
    Schema schema, {
    String dbPath = 'default.db',
    bool relativeToSqflitePath = true,
    List<Migration> migrations = const [],
    bool nukeDb = false,
  }) {
    if (initialised) return Future.value();

    if (_initialisationCompleter == null) {
      _initialisationCompleter = Completer();

      this.schema = schema;
      this.migrations = migrations;
      this.schema.tables[metaTableName] = Table(columns: [Column.integer('current_version')], name: metaTableName);

      tables = schema.tables.map((key, table) => MapEntry(key, table.toDbTable(this)));

      _open(
        dbPath,
        nukeDb: nukeDb,
        relativeToSqflitePath: relativeToSqflitePath,
      ).whenComplete(() => _initialisationCompleter!.complete());
    }

    return _initialisationCompleter!.future;
  }

  Future<void> _open(
    String dbPath, {
    bool nukeDb = false,
    bool relativeToSqflitePath = false,
  }) async {
    if (Platform.isWindows && Platform.isLinux) {
      sql.sqfliteFfiInit();
    }
    sql.databaseFactory = sql.databaseFactoryFfi;

    final databasesPath = await sql.getDatabasesPath();

    if (!relativeToSqflitePath) {
      if (nukeDb) await sql.deleteDatabase(dbPath);
      if (Platform.isWindows) {
        _db = await sqfliteFfi.openDatabase(dbPath);
      } else {
        _db = await sql.openDatabase(dbPath);
      }
      print(_db!.path);
    } else {
      if (Platform.isWindows) {
        _db = await sqfliteFfi.openDatabase('$databasesPath/$dbPath');
      } else {
        _db = await sql.openDatabase('$databasesPath/$dbPath');
      }
    }

    for (final table in schema.tables.values) {
      print("executing:");
      print(table.toSql());

      await _db!.execute(table.toSql());
    }

    await applyMigrations();
  }

  Future<void> applyMigrations() async {
    final metaTableQuery = await metaTable.query(Query.all());
    final currentVersion = metaTableQuery.firstOrNull?['current_version'] as int? ?? migrations.length;

    print('currentVersion: $currentVersion');

    for (var i = currentVersion; i < migrations.length; i++) {
      await migrations.elementAt(i)(this, i);
    }

    if (metaTableQuery.isEmpty) {
      await metaTable.insert({'current_version': migrations.length});
    } else {
      await metaTable.updateId({'current_version': migrations.length}, 0);
    }
  }

  Future<void> addTable(Table table) async {
    schema.tables[table.name] = table;
    tables[table.name] = DbTable(this, table);

    await execute(table.toSql());
  }

  Future<void> close() {
    if (_db == null) throw Exception('DB is not open');

    _initialisationCompleter = null;

    return _db!.close();
  }

  Future<void> deleteDatabase() {
    if (_db?.isOpen == true) throw Exception('DB is open, please close first');

    return sql.deleteDatabase(_db!.path);
  }

  Future<void> execute(String sql) async {
    print('executing: $sql');
    await _db!.execute(sql);
  }

  Future<void> executeBuilder(StatementBuilder Function(StatementBuilder builder) builder) => execute(builder(StatementBuilder()).toSql());

  Future<int> insert(Table table, Map<String, Object?> values) async {
    final newIndex = await _db!.insert(table.name, values);

    _tableUpdates.add(table);

    return newIndex;
  }

  /// Returns number of rows affected
  Future<int> delete(Table table, Query query) async {
    final newIndex = await _db!.delete(table.name, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableUpdates.add(table);

    return newIndex;
  }

  Future<int> update(Table table, Map<String, Object?> values, Query query) async {
    final newIndex = await _db!.update(table.name, values, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableUpdates.add(table);

    return newIndex;
  }

  Future<List<Map<String, Object?>>> rawQuery(String query) async {
    return await _db!.rawQuery(query);
  }

  Future<List<Map<String, Object?>>> query(Table table, Query query) async {
    return await _db!.rawQuery(table.queryString(query));
  }

  Stream<List<Map<String, Object?>>> watchQuery(Table table, Query query) async* {
    yield await this.query(table, query);

    await for (final _ in _tableUpdates.stream.where((event) => event.name == table.name)) {
      yield await this.query(table, query);
    }
  }

  /// Provides a safe builder access for querying the database when you are unsure of the initialisation status
  Stream<List<T>> when<T>(Stream<List<T>> Function(XqfliteDatabase db) builder) async* {
    await future;

    yield* builder(this);
  }

  sql.Batch getRawBatch() => _db!.batch();

  Future<void> batch(void Function(Batch batch) executor) async {
    final batch = Batch(this);

    executor(batch);

    final result = await batch.commit();

    for (final update in result.updates) {
      _tableUpdates.add(update);
    }
  }
}
