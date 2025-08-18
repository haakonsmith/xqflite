import 'dart:async';

import 'package:xqflite/src/exceptions.dart';
import 'package:xqflite/src/statements.dart';
import 'package:xqflite/src/validation.dart';
import 'package:xqflite/xqflite.dart';

/// Stupid workaround for private class
final class DynTransactionWrapper {
  dynamic _inner;

  DynTransactionWrapper(this._inner);

  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? named,
    List<dynamic>? positional,
  }) =>
      _inner.query(sql, named: named, positional: positional);

  Future<int> execute(
    String sql, {
    Map<String, dynamic>? named,
    List<dynamic>? positional,
  }) =>
      _inner.execute(sql, named: named, positional: positional);

  Future<void> commit() => _inner.commit();

  Future<void> rollback() => _inner.rollback();
}

typedef TransactionResult = ({
  List<Table> changedTables,
  List<TableUpdate> tableUpdates,
  List<TableDelete> tableDeletes,
  List<TableInsert> tableInserts,
});

final class Transaction {
  /// A batch is just a string buffer that we write to
  final DynTransactionWrapper txn;
  final List<Table> _tableChanges = [];
  final List<TableUpdate> _updates = [];
  final List<TableInsert> _inserts = [];
  final List<TableDelete> _deletes = [];

  Transaction(this.txn);

  TransactionTable<Key> withTable<Key>(Table<Key> table) => TransactionTable<Key>(this, table);
  TransactionTableWithConverter<Key, T> withTableAndConverter<Key, T>(Table<Key> table, Converter<T> converter) => withTable(table).withConverter(converter);
  TransactionTableWithConverter<Key_, T> bind<Key_, T>(DbTableWithConverter<Key_, T> table) => withTable(table.table.table).withConverter(table.converter);

  Future<TransactionResult> commit() async {
    await txn.commit();

    return (
      changedTables: _tableChanges,
      tableUpdates: _updates,
      tableInserts: _inserts,
      tableDeletes: _deletes,
    );
  }

  Future<void> rollback() async {
    await txn.rollback();
  }

  /// This executes raw sql on the batch
  ///
  /// This is useful for things like `CREATE TABLE` or `DROP TABLE`
  ///
  /// It does not update the table updates
  Future<int> execute(String sql, {List<Object?>? positional}) async {
    return await txn.execute(sql, positional: positional);
  }

  Future<KeyType> insert<KeyType>(Table<KeyType> table, Map<String, Object?> values, {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    try {
      final insertionValues = table.columns.validateMapExcept(table.columns.preprocessMap(values));
      final arguments = insertionValues.entries.toList();
      final newKey = await txn.query(
        table.buildInsertStatement(columnNames: arguments.map((e) => e.key), onConflict: conflictAlgorithm),
        positional: arguments.map((e) => e.value).toList(),
      );

      _tableChanges.add(table);
      _inserts.add((table, values, conflictAlgorithm));

      return newKey.first.values.first as KeyType;
    } catch (e, stack) {
      print(stack);
      throw XqfliteGenericException(e);
    }
  }

  Future<int> delete(Table table, Query query) async {
    final where = query.whereStringOrNull();
    final whereClause = where ?? "";

    final count = await txn.execute("""DELETE FROM ${table.name} WHERE $whereClause""", positional: query.valuesOrNull);

    _tableChanges.add(table);
    _deletes.add((table, query));

    return count;
  }

  Future<int> update(Table table, Map<String, Object?> values, Query query) async {
    final count = await txn.execute(buildUpdateStatement(table.name, values, query), positional: values.values.toList() + (query.valuesOrNull ?? []));

    _tableChanges.add(table);
    _updates.add((table, query, values));

    return count;
  }
}

final class TransactionTable<KeyType> {
  final Transaction txn;
  final Table<KeyType> table;

  const TransactionTable(this.txn, this.table);

  TransactionTableWithConverter<KeyType, T> withConverter<T>(Converter<T> converter) => TransactionTableWithConverter(this, converter);
  TransactionTable innerJoin(DbTable joinee, Query on) => TransactionTable(txn, table.innerJoin(joinee.table, on));

  Future<KeyType> insert(Map<String, Object?> values) {
    return txn.insert<KeyType>(table, values);
  }

  Future<int> delete(Query query) {
    return txn.delete(table, query);
  }

  Future<int> update(Map<String, Object?> values, Query query) {
    return txn.update(table, values, query);
  }
}

final class TransactionTableWithConverter<KeyType, T> {
  final Converter<T> converter;
  final TransactionTable<KeyType> txn;

  const TransactionTableWithConverter(this.txn, this.converter);

  TransactionTable innerJoin(DbTable joinee, Query on) => txn.innerJoin(joinee, on);

  Future<KeyType> insert(T value) {
    return txn.insert(converter.toDb(value));
  }

  Future<int> delete(Query query) {
    return txn.delete(query);
  }

  Future<int> update(T value, Query query) {
    return txn.update(converter.toDb(value), query);
  }

  Future<void> updateId(T value, KeyType id) async {
    await txn.update(
        converter.toDb(value),
        txn.table.primaryKey.query.withValues([
          id.toString(),
        ]));
  }

  Future<void> deleteId(KeyType id) async {
    await txn.delete(txn.table.primaryKey.query.withValues([
      id.toString(),
    ]));
  }
}
