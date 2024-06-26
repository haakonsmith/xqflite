import 'package:flutter/foundation.dart';
import 'package:xqflite/src/batch.dart';
import 'package:xqflite/xqflite.dart';
import 'package:xqflite/src/validation.dart';

class DbTable {
  final QueryExecutor database;
  final Table table;

  const DbTable(this.database, this.table);

  DbTable innerJoin(DbTable joinee, Query on) => DbTable(database, table.innerJoin(joinee.table, on));
  DbTable groupBy(List<String> groupProperties) => DbTable(database, table.groupBy(groupProperties));
  DbTableWithConverter<T> withConverter<T>(Converter<T> converter) => DbTableWithConverter(this, converter);

  Future<List<RawData>> query(Query query) async {
    return await database.query(table, query);
  }

  Stream<List<RawData>> watch(Query query) {
    return database.watchQuery(table, query);
  }

  /// Returns number of rows affected
  Future<int> delete(Query query) async {
    return await database.delete(table, query);
  }

  Future<int> insert(RawData value, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    return await database.insert(
      table,
      table.columns.validateMapExcept(value),
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<int> update(Map<String, Object?> values, Query query) async {
    table.columns.where((column) => values.values.contains(column.name)).toList().validateMap(values)?.throwSelf();

    return await database.update(table, values, query);
  }

  Future<void> batch(void Function(BatchTable batch) executor) {
    return database.batch((batch) {
      executor(batch.withTable(table));
    });
  }

  PartialQuery idQuery() => table.primaryKey.query;
  Query single<I>(I id) => table.primaryKey.query.withValues([id.toString()]);

  Future<int> deleteId(int id) => delete(single(id));
  Future<int> updateId(Map<String, Object?> values, int id) => update(values, single(id));
}

final class DbTableWithConverter<T> {
  final Converter<T> converter;
  final DbTable table;

  const DbTableWithConverter(this.table, this.converter);

  // DbTable leftJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.leftJoin(joinee.table, on);
  // DbTable rightJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.rightJoin(joinee.table, on);
  // DbTable fullOuterJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.fullOuterJoin(joinee.table, on);
  DbTable innerJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.innerJoin(joinee.table, on);
  String get tableName => table.table.name;

  T fromDb(RawData data) {
    try {
      return converter.fromDb(data);
    } on TypeError catch (e) {
      print('Converter Type Error found, raw data: $data\nerror: $e');

      rethrow;
    }
  }

  Future<List<T>> query(Query query) async {
    if (kDebugMode && query.columns != null) {
      debugPrint('Warning: columns are ignored in query for table $tableName. If you want to select specific columns, do not use a converter.');
    }

    return (await table.query(query.withoutColumns())) //
        .map((e) => fromDb(e))
        .toList();
  }

  Stream<List<T>> watch(Query query) {
    return table.watch(query).map((e) => e.map((l) => fromDb(l)).toList());
  }

  Future<int> delete(Query query) async {
    return table.delete(query);
  }

  Future<int> insert(T value, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    return table.insert(converter.toDb(value), conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(T value, Query query) async {
    return table.update(converter.toDb(value), query);
  }

  Future<void> batch(void Function(BatchTableWithConverter<T> batch) executor) {
    return table.batch((batch) {
      executor(batch.withConverter(converter));
    });
  }

  PartialQuery idQuery() => table.idQuery();
  Query single<I>(I id) => table.single(id);

  Future<T?> queryId<I>(I id) => query(single(id)).then((value) => value.firstOrNull);
  Future<int> deleteId<I>(I id) => delete(single(id));
  Future<int> updateId<I>(T value, I id) => update(value, single(id));
}
