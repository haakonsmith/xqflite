import 'dart:async';
import 'dart:io';

import 'package:async_locks/async_locks.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:libsql_dart/libsql_dart.dart';
// import 'package:xqflite/src/batch.dart';
import 'package:xqflite/src/column.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:xqflite/src/exceptions.dart';
import 'package:xqflite/src/statements.dart';
import 'package:xqflite/src/transaction.dart';
import 'package:xqflite/src/validation.dart';
import 'package:xqflite/xqflite.dart';

typedef TableUpdate = (Table, Query, Map<String, Object?>);
typedef TableInsert = (Table, Map<String, Object?>, ConflictAlgorithm);
typedef TableDelete = (Table, Query);

class XqfliteSqlBuilder extends StatementBuilder {
  final XqfliteDatabase database;

  XqfliteSqlBuilder(this.database);

  Future<void> execute() async {
    await database.execute(toSql());
  }
}

abstract interface class QueryExecutor {
  Future<int> execute(String string);

  Future<int> update(Table table, Map<String, Object?> values, Query query);
  Future<int> delete(Table table, Query query);
  Future<KeyType> insert<KeyType>(Table<KeyType> table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort});

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, {
    Map<String, dynamic>? named,
    List<dynamic>? positional,
  });
  Future<List<Map<String, Object?>>> query(Table table, Query query);
  Stream<List<Map<String, Object?>>> watchQuery(Table table, Query query);
}

class XqfliteDatabase implements QueryExecutor {
  static const metaTableName = '__META_TABLE__';

  DbTable get metaTable => tables[metaTableName]!;

  Completer<void>? _initialisationCompleter;
  bool get initialised => _initialisationCompleter?.isCompleted ?? false;

  Future<void>? get future => _initialisationCompleter?.future;

  final Lock lock = Lock();

  LibsqlClient? client;

  final StreamController<Table> _tableChangeController = StreamController.broadcast();
  final StreamController<TableDelete> _deleteController = StreamController.broadcast();
  final StreamController<TableInsert> _insertController = StreamController.broadcast();
  final StreamController<TableUpdate> _updateController = StreamController.broadcast();
  late Schema schema;
  late Map<String, DbTable> tables;

  String? get path => client?.url;

  Future<void> Function(XqfliteDatabase db)? onBeforeMigration;

  Future<void> connect(
    LibsqlClient client,
    Schema schema, {
    Future<void> Function(XqfliteDatabase db)? onBeforeMigration,
  }) async {
    if (initialised) return;

    if (_initialisationCompleter == null) {
      _initialisationCompleter = Completer();

      this.schema = schema;
      this.schema.tables[metaTableName] = Table(columns: [Column.integer('current_version')], name: metaTableName);
      this.onBeforeMigration = onBeforeMigration;

      tables = schema.tables.map((key, table) => MapEntry(key, table.toDbTable(this)));

      this.client = client;

      await this.client!.connect();

      for (final table in schema.tables.values) {
        await execute(table.toSql());
      }

      await onBeforeMigration?.call(this);
      await _applyMigrations();

      _initialisationCompleter?.complete();
    }

    await _initialisationCompleter!.future;
  }

  Future<void> _applyMigrations() async {
    final migrations = schema.migrations..sortBy<num>((element) => element.version);
    final latestMigration = migrations.lastOrNull;
    var version = ((await rawQuery('PRAGMA user_version')).first['user_version'] as int? ?? 0);

    // If version == 0, then we haven't run any migrations
    if (version == 0) {
      // We transform from n space to n + 1 which is what it expected
      version = (latestMigration?.version ?? 0) + 1;
      // Run this then so that it doesn't run a migration
      version++;
    }

    for (final migration in migrations) {
      final migrationVersion = migration.version + 1;

      if (migrationVersion < version) continue;
      if (migrationVersion > version) throw MigrationMissingError(version);
      if (migrationVersion == version) {
        await migration.migrator(this, migration.version);

        version++;
      }
    }

    await execute('PRAGMA user_version = $version;');
  }

  Future<void> addTable(Table table) async {
    schema.tables[table.name] = table;
    tables[table.name] = DbTable(this, table);

    await execute(table.toSql());
  }

  DbTable<Key> getTable<Key>(String name) => tables[name] as DbTable<Key>;
  DbTableWithConverter<Key, Value> getTableWithConverter<Key, Value>(String name, Converter<Value> converter) =>
      (tables[name] as DbTable<Key>).withConverter(converter);

  /// Creates .bak version of this db
  Future<void> backup() async {
    clone("$path.bak");
  }

  Future<void> clone(String newPath) async {
    if (path != null) {
      if (path == ":memory:") {
        debugPrint("Skipping backup for in memory db");
      } else {
        await File(path!).copy(newPath);
      }
    }
  }

  Future<void> close() async {
    if (client == null) throw Exception('DB is not open');

    _initialisationCompleter = null;

    await client!.dispose();
  }

  // Future<void> deleteDatabase() {
  //   if (client == null) throw Exception('DB is open, please close first');

  //   return sql.deleteDatabase(client!.path);
  // }

  @override
  Future<int> execute(
    String sql, {
    Map<String, dynamic>? named,
    List<dynamic>? positional,
  }) async {
    return await lock.run(() async => await client!.execute(sql, named: named, positional: positional));
  }

  Future<void> executeBuilder(StatementBuilder Function(StatementBuilder builder) builder) => execute(builder(StatementBuilder()).toSql());

  @override
  Future<KeyType> insert<KeyType>(Table<KeyType> table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    try {
      // final newKey = await _db!.insert(table.name,
      //     table.columns.validateMapExcept(table.columns.preprocessMap(values)),
      //     conflictAlgorithm: conflictAlgorithm.intoPrivate());

      final insertionValues = table.columns.validateMapExcept(table.columns.preprocessMap(values));
      final arguments = insertionValues.entries.toList();
      final newKey = await lock.run(() async => await client!.query(
            table.buildInsertStatement(columnNames: arguments.map((e) => e.key), onConflict: conflictAlgorithm),
            positional: arguments.map((e) => e.value).toList(),
          ));

      _tableChangeController.add(table);
      _insertController.add((table, values, conflictAlgorithm));

      return newKey.first.values.first as KeyType;
    } catch (e, stack) {
      print(stack);
      throw XqfliteGenericException(e);
    }
  }

  /// Returns number of rows affected
  @override
  Future<int> delete(Table table, Query query) async {
    final where = query.whereStringOrNull();
    final whereClause = where ?? "";

    final count = await lock.run(() async => await client!.execute("""DELETE FROM ${table.name} WHERE $whereClause""", positional: query.valuesOrNull));

    _tableChangeController.add(table);
    _deleteController.add((table, query));

    return count;
  }

  /// Convenience method for updating rows in the database. Returns the number of changes made
  ///
  /// Update [table] with [values], a map from column names to new column values. null is a valid value that will be translated to NULL.
  @override
  Future<int> update(Table table, Map<String, Object?> values, Query query) async {
    // final count = await client!.execute(table.name, values, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);
    final count = await lock.run(
        () async => await client!.execute(buildUpdateStatement(table.name, values, query), positional: values.values.toList() + (query.valuesOrNull ?? [])));

    _tableChangeController.add(table);
    _updateController.add((table, query, values));

    return count;
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String query, {
    Map<String, dynamic>? named,
    List<dynamic>? positional,
  }) async {
    return await lock.run(() async => await client!.query(query, named: named, positional: positional));
  }

  @override
  Future<List<Map<String, Object?>>> query(Table table, Query query) async {
    return await lock.run(() async => await client!.query(buildQueryStatement(table, query), positional: query.valuesOrNull));
  }

  @override
  Stream<List<Map<String, Object?>>> watchQuery(Table table, Query query) async* {
    yield await this.query(table, query);

    await for (final _ in _tableChangeController.stream.where((event) => event.name == table.name)) {
      yield await this.query(table, query);
    }
  }

  /// Returns a stream of any table change
  Stream<Table> get tableChangeStream => _tableChangeController.stream;
  Stream<TableUpdate> get tableUpdateStream => _updateController.stream;
  Stream<TableInsert> get tableInsertStream => _insertController.stream;
  Stream<TableDelete> get tableDeleteStream => _deleteController.stream;

  /// Provides a safe builder access for querying the database when you are unsure of the initialisation status
  Stream<List<T>> when<T>(Stream<List<T>> Function(XqfliteDatabase db) builder) async* {
    await future;

    yield* builder(this);
  }

  // sql.Batch getRawBatch() => client!.batch();

  // @override
  Future<void> transaction(Future<void> Function(Transaction batch) executor) async {
    final txn = await lock.run(() async => await client!.transaction());

    final batch = Transaction(DynTransactionWrapper(txn));

    try {
      await executor(batch);

      final result = await batch.commit();

      for (final update in result.changedTables) {
        _tableChangeController.add(update);
      }

      for (final update in result.tableUpdates) {
        _updateController.add(update);
      }
    } catch (e) {
      batch.rollback();
      rethrow;
    }
  }
}
