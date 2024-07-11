import 'package:flutter/foundation.dart';
import 'package:xqflite/src/batch.dart';
import 'package:xqflite/xqflite.dart';
import 'package:xqflite/src/validation.dart';

class DbTable<KeyType> {
  final QueryExecutor database;
  final Table<KeyType> table;

  const DbTable(this.database, this.table);

  DbTable innerJoin(DbTable joinee, Query on) => DbTable(database, table.innerJoin(joinee.table, on));
  DbTable groupBy(List<String> groupProperties) => DbTable(database, table.groupBy(groupProperties));
  DbTableWithConverter<KeyType, T> withConverter<T>(Converter<T> converter) => DbTableWithConverter(this, converter);

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

  Future<KeyType> insert(RawData value, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    return await database.insert(
      table,
      value,
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
  Query single(KeyType id) => table.primaryKey.query.withValues([id.toString()]);

  Future<int> deleteId(KeyType id) => delete(single(id));
  Future<int> updateId(Map<String, Object?> values, KeyType id) => update(values, single(id));
}

final class DbTableWithConverter<KeyType, T> {
  final Converter<T> converter;
  final DbTable<KeyType> table;

  const DbTableWithConverter(this.table, this.converter);

  // DbTable leftJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.leftJoin(joinee.table, on);
  // DbTable rightJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.rightJoin(joinee.table, on);
  // DbTable fullOuterJoin<K>(DbTableWithConverter<K> joinee, Query on) => table.fullOuterJoin(joinee.table, on);
  DbTable innerJoin<K>(DbTableWithConverter<KeyType, K> joinee, Query on) => table.innerJoin(joinee.table, on);
  String get tableName => table.table.name;

  T fromDb(RawData data) {
    try {
      return converter.fromDb(data);
    } on TypeError catch (e, stack) {
      print('Converter Type Error found, raw data: $data\nerror: $e\nstack: $stack');

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

  Future<KeyType> insert(T value, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
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
  Query single(KeyType id) => table.single(id);

  Future<T?> queryId(KeyType id) => query(single(id)).then((value) => value.firstOrNull);
  Future<int> deleteId(KeyType id) => delete(single(id));
  Future<int> updateId(T value, KeyType id) => update(value, single(id));
}
