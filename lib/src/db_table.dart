import 'package:xqflite/xqflite.dart';
import 'package:xqflite/src/validation.dart';

class DbTable {
  final XqfliteDatabase database;
  final Table table;

  const DbTable(this.database, this.table);

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

  Future<int> insert(RawData value) async {
    return await database.insert(
      table,
      table.columns.validateMapExcept(value),
    );
  }

  Future<int> update(Map<String, Object?> values, Query query) async {
    table.columns.validateMap(values)?.throwSelf();

    return await database.update(table, values, query);
  }

  PartialQuery idQuery() => table.primaryKey.query;
  Query single(int id) => table.primaryKey.query.withValues([id.toString()]);

  Future<int> deleteId(int id) => delete(single(id));
  Future<int> updateId(Map<String, Object?> values, int id) => update(values, single(id));
}

final class DbTableWithConverter<T> {
  final Converter<T> converter;
  final DbTable table;

  const DbTableWithConverter(this.table, this.converter);

  T fromDb(RawData data) {
    try {
      return converter.fromDb(data);
    } on TypeError catch (_) {
      print('Converter Type Error found, raw data: $data');

      rethrow;
    }
  }

  Future<List<T>> query(Query query) async {
    return (await table.query(query)) //
        .map((e) => fromDb(e))
        .toList();
  }

  Stream<List<T>> watch(Query query) {
    return table.watch(query).map((e) => e.map((l) => fromDb(l)).toList());
  }

  Future<int> delete(Query query) async {
    return table.delete(query);
  }

  Future<int> insert(T value) async {
    return table.insert(converter.toDb(value));
  }

  Future<int> update(T value, Query query) async {
    return table.update(converter.toDb(value), query);
  }

  PartialQuery idQuery() => table.idQuery();
  Query single(int id) => table.single(id);

  Future<int> deleteId(int id) => delete(single(id));
  Future<int> updateId(T value, int id) => update(value, single(id));
}
