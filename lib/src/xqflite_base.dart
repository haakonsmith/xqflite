import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:xqflite/src/batch.dart';
import 'package:xqflite/src/column.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:xqflite/src/exceptions.dart';
import 'package:xqflite/xqflite.dart';

enum ConflictAlgorithm {
  /// This will replace the offending data
  ///
  /// When a UNIQUE or PRIMARY KEY constraint violation occurs, the REPLACE algorithm deletes pre-existing rows that are causing the constraint violation prior to inserting or updating the current row and the command continues executing normally. If a NOT NULL constraint violation occurs, the REPLACE conflict resolution replaces the NULL value with the default value for that column, or if the column has no default value, then the ABORT algorithm is used. If a CHECK constraint or foreign key constraint violation occurs, the REPLACE conflict resolution algorithm works like ABORT.
  ///
  /// When the REPLACE conflict resolution strategy deletes rows in order to satisfy a constraint, delete triggers fire if and only if recursive triggers are enabled.
  ///
  /// The update hook is not invoked for rows that are deleted by the REPLACE conflict resolution strategy. Nor does REPLACE increment the change counter. The exceptional behaviors defined in this paragraph might change in a future release.
  replace,

  /// This is the default behaviour
  ///
  /// When an applicable constraint violation occurs, the ABORT resolution algorithm aborts the current SQL statement with an SQLITE_CONSTRAINT error and backs out any changes made by the current SQL statement; but changes caused by prior SQL statements within the same transaction are preserved and the transaction remains active. This is the default behavior and the behavior specified by the SQL standard.
  abort
}

extension _FromPublicConflictAlgorithm on ConflictAlgorithm {
  sql.ConflictAlgorithm intoPrivate() => switch (this) {
        ConflictAlgorithm.replace => sql.ConflictAlgorithm.replace,
        ConflictAlgorithm.abort => sql.ConflictAlgorithm.abort,
      };
}

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
  Future<int> update(Table table, Map<String, Object?> values, Query query);
  Future<int> delete(Table table, Query query);
  Future<int> insert(Table table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort});

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

  final StreamController<Table> _tableChangeController = StreamController.broadcast();
  final StreamController<TableDelete> _deleteController = StreamController.broadcast();
  final StreamController<TableInsert> _insertController = StreamController.broadcast();
  final StreamController<TableUpdate> _updateController = StreamController.broadcast();
  late Schema schema;
  late Map<String, DbTable> tables;

  String? get path => _db?.path;

  Future<void> Function(XqfliteDatabase db)? onBeforeMigration;

  Future<void> open(
    Schema schema, {
    String dbPath = 'default.db',
    bool nukeDb = false,
    Future<void> Function(XqfliteDatabase db)? onBeforeMigration,
  }) async {
    if (initialised) return;

    if (_initialisationCompleter == null) {
      _initialisationCompleter = Completer();

      this.schema = schema;
      this.schema.tables[metaTableName] = Table(columns: [Column.integer('current_version')], name: metaTableName);
      this.onBeforeMigration = onBeforeMigration;

      tables = schema.tables.map((key, table) => MapEntry(key, table.toDbTable(this)));

      await _open(
        dbPath,
        nukeDb: nukeDb,
      ).whenComplete(() => _initialisationCompleter!.complete());
    }

    await _initialisationCompleter!.future;
  }

  Future<void> _open(
    String dbPath, {
    bool nukeDb = false,
  }) async {
    if (Platform.isWindows || Platform.isLinux) {
      sql.sqfliteFfiInit();
    }

    sql.databaseFactoryOrNull = sql.databaseFactoryFfi;

    if (nukeDb) await sql.deleteDatabase(dbPath);
    _db = await sql.openDatabase(dbPath);

    for (final table in schema.tables.values) {
      await _db!.execute(table.toSql());
    }

    await onBeforeMigration?.call(this);
    await _applyMigrations();
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

    await execute('PRAGMA user_version = $version');
  }

  Future<void> addTable(Table table) async {
    schema.tables[table.name] = table;
    tables[table.name] = DbTable(this, table);

    await execute(table.toSql());
  }

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
    await _db!.execute(sql);
  }

  Future<void> executeBuilder(StatementBuilder Function(StatementBuilder builder) builder) => execute(builder(StatementBuilder()).toSql());

  @override
  Future<int> insert(Table table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    try {
      final newIndex = await _db!.insert(table.name, values, conflictAlgorithm: conflictAlgorithm.intoPrivate());

      _tableChangeController.add(table);
      _insertController.add((table, values, conflictAlgorithm));

      return newIndex;
    } catch (e) {
      throw XqfliteGenericException(e);
    }
  }

  /// Returns number of rows affected
  @override
  Future<int> delete(Table table, Query query) async {
    final count = await _db!.delete(table.name, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableChangeController.add(table);
    _deleteController.add((table, query));

    return count;
  }

  /// Convenience method for updating rows in the database. Returns the number of changes made
  ///
  /// Update [table] with [values], a map from column names to new column values. null is a valid value that will be translated to NULL.
  @override
  Future<int> update(Table table, Map<String, Object?> values, Query query) async {
    final count = await _db!.update(table.name, values, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableChangeController.add(table);
    _updateController.add((table, query, values));

    return count;
  }

  Future<List<Map<String, Object?>>> rawQuery(String query) async {
    return await _db!.rawQuery(query);
  }

  @override
  Future<List<Map<String, Object?>>> query(Table table, Query query) async {
    return await _db!.query(
      table.tableIdQuery(),
      where: query.whereStringOrNull(),
      whereArgs: query.valuesOrNull,
      orderBy: query.orderByString(),
      distinct: query.distinct,
      columns: query.columns,
    );
  }

  @override
  Stream<List<Map<String, Object?>>> watchQuery(Table table, Query query) async* {
    yield await this.query(table, query);

    await for (final _ in _tableChangeController.stream.where((event) => event.name == table.name)) {
      yield await this.query(table, query);
    }
  }

  @Deprecated("This is deprecated, use [tableChangeStream] instead")
  Stream<Table> watchUpdates() => _tableChangeController.stream;

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

  sql.Batch getRawBatch() => _db!.batch();

  @override
  Future<List<Object?>> batch(void Function(Batch batch) executor) async {
    final batch = Batch(this);

    executor(batch);

    final result = await batch.commit();

    for (final update in result.changedTables) {
      _tableChangeController.add(update);
    }

    for (final update in result.tableUpdates) {
      _updateController.add(update);
    }

    return result.rawResult;
  }
}
