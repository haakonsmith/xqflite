import 'dart:async';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:xqflite/src/validation.dart';
import 'package:xqflite/xqflite.dart';

typedef BatchResult = ({
  List<Table> changedTables,
  List<TableUpdate> tableUpdates,
  List<TableDelete> tableDeletes,
  List<TableInsert> tableInserts,
  List<Object?> rawResult,
});

final class Batch {
  final sqflite.Batch batch;
  final List<Table> _tableChanges = [];
  final List<TableUpdate> _updates = [];
  final List<TableInsert> _inserts = [];
  final List<TableDelete> _deletes = [];

  Batch(XqfliteDatabase database) : batch = database.getRawBatch();

  BatchTable withTable(Table table) => BatchTable(this, table);
  BatchTableWithConverter<T> withTableAndConverter<T>(Table table, Converter<T> converter) => withTable(table).withConverter(converter);
  BatchTableWithConverter<T> bind<Key_, T>(DbTableWithConverter<Key_, T> table) => withTable(table.table.table).withConverter(table.converter);

  Future<BatchResult> commit() async {
    return (
      rawResult: await batch.commit(),
      changedTables: _tableChanges,
      tableUpdates: _updates,
      tableInserts: _inserts,
      tableDeletes: _deletes,
    );
  }

  /// This executes raw sql on the batch
  ///
  /// This is useful for things like `CREATE TABLE` or `DROP TABLE`
  ///
  /// It does not update the table updates
  void execute(String sql, [List<Object?>? arguments]) async {
    batch.execute(sql, arguments);
  }

  void insert(Table table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    final insertionValues = table.columns.validateMapExcept(table.columns.preprocessMap(values));

    batch.insert(table.name, insertionValues);

    _tableChanges.add(table);
    _inserts.add((table, insertionValues, conflictAlgorithm));
  }

  void delete(Table table, Query query) async {
    batch.delete(table.name, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableChanges.add(table);
    _deletes.add((table, query));
  }

  void update(Table table, Map<String, Object?> values, Query query) async {
    batch.update(table.name, values, where: query.whereStringOrNull(), whereArgs: query.valuesOrNull);

    _tableChanges.add(table);
    _updates.add((table, query, values));
  }
}

final class BatchTable {
  final Batch batch;
  final Table table;

  const BatchTable(this.batch, this.table);

  BatchTableWithConverter<T> withConverter<T>(Converter<T> converter) => BatchTableWithConverter(this, converter);
  BatchTable innerJoin(DbTable joinee, Query on) => BatchTable(batch, table.innerJoin(joinee.table, on));

  void insert(Map<String, Object?> values) {
    batch.insert(table, values);
  }

  void delete(Query query) {
    batch.delete(table, query);
  }

  void update(Map<String, Object?> values, Query query) {
    batch.update(table, values, query);
  }
}

final class BatchTableWithConverter<T> {
  final Converter<T> converter;
  final BatchTable batch;

  const BatchTableWithConverter(this.batch, this.converter);

  BatchTable innerJoin(DbTable joinee, Query on) => batch.innerJoin(joinee, on);

  void insert(T value) {
    batch.insert(converter.toDb(value));
  }

  void delete(Query query) {
    batch.delete(query);
  }

  void update(T value, Query query) {
    batch.update(converter.toDb(value), query);
  }

  void updateId<K>(T value, K id) {
    batch.update(
        converter.toDb(value),
        batch.table.primaryKey.query.withValues([
          id.toString(),
        ]));
  }

  void deleteId<K>(K id) {
    batch.delete(batch.table.primaryKey.query.withValues([
      id.toString(),
    ]));
  }
}
