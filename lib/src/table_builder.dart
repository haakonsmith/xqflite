import 'package:collection/collection.dart';
import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/exceptions.dart';
import 'package:xqflite/src/table.dart';

import 'data_types.dart';

enum TriggerVerb {
  delete("DELETE"),
  insert("INSERT"),
  update("UPDATE");

  final String sql;

  const TriggerVerb(this.sql);
}

enum TriggerTemporality {
  before("BEFORE"),
  after("AFTER"),
  insteadOf("INSTEAD OF");

  final String sql;

  const TriggerTemporality(this.sql);
}

/// A builder for sql triggers;
final class TriggerBuilder {
  TriggerBuilder(this.tableName, this.triggerName, {required this.verb, this.temporality = TriggerTemporality.before});

  final String tableName;
  final String triggerName;
  TriggerTemporality temporality;
  TriggerVerb verb;

  String sql(String statements) => """CREATE TRIGGER IF NOT EXISTS $triggerName ${temporality.sql} ${verb.sql} ON $tableName
BEGIN
  $statements
END;
  """;
}

final class TableBuilder<Key> {
  final String tableName;
  final List<String Function(Table table)> sqlBuilders = [];
  final List<Column> columns = [];

  TableBuilder(this.tableName);

  TableBuilder<Key> text(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.text, nullable: nullable, unique: unique));
  TableBuilder<Key> integer(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.integer, nullable: nullable, unique: unique));
  TableBuilder<Key> bytes(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.bytes, nullable: nullable, unique: unique));
  TableBuilder<Key> real(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.real, nullable: nullable, unique: unique));
  TableBuilder<Key> boolean(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.boolean, nullable: nullable, unique: unique));

  TableBuilder<Key> dateTime(String name, {bool nullable = false, bool unique = false}) =>
      this..columns.add(GenericColumn(name, DataType.dateTime, nullable: nullable, unique: unique));
  TableBuilder<int> primaryKey(String name) => TableBuilder((this..columns.add(PrimaryKeyColumn(name))).tableName)
    ..columns.addAll(columns)
    ..sqlBuilders.addAll(sqlBuilders);

  TableBuilder<String> primaryKeyCuid(String name) => TableBuilder((this..columns.add(PrimaryKeyCuidColumn(name))).tableName)
    ..columns.addAll(columns)
    ..sqlBuilders.addAll(sqlBuilders);
  TableBuilder<String> primaryKeyUuid(String name) => TableBuilder((this..columns.add(PrimaryKeyUuidColumn(name))).tableName)
    ..columns.addAll(columns)
    ..sqlBuilders.addAll(sqlBuilders);
  TableBuilder<Key> reference(String name, Table table,
          {bool nullable = false, CascadeOperation? onUpdate, CascadeOperation? onDelete, DataAffinity type = DataAffinity.integer}) =>
      this..columns.add(ReferenceColumn(name, references: table, nullable: nullable, onDelete: onDelete, onUpdate: onUpdate, type: type));

  /// This additional sql will get executed immediately after table creation,
  /// This is useful for triggers, keep in mind all triggers written like this should have "IF NOT EXISTS" as the will get executed regardless
  /// Initalisation of this property is deffered so it will always have all columns within it.
  TableBuilder<Key> additionalSql(String Function(Table table) sql) => this..sqlBuilders.add(sql);

  TableBuilder<Key> trigger(
    String Function(Table table) sql, {
    required String name,
    required TriggerVerb verb,
    TriggerTemporality temporality = TriggerTemporality.before,
  }) =>
      this..sqlBuilders.add((table) => TriggerBuilder(table.name, name, verb: verb, temporality: temporality).sql(sql(table)));

  Table<Key> build({bool withoutRowId = false}) {
    final table = Table(name: tableName, columns: columns);

    if (withoutRowId && columns.firstWhereOrNull((col) => col is IntoPrimaryKey) == null) {
      throw XqfliteGenericException("Failed to build table, table has no primary key");
    }

    return Table<Key>(
      name: tableName,
      columns: columns,
      childJoins: [],
      withoutRowId: withoutRowId,
      additionalSql: sqlBuilders.map((f) => f(table)).join("\n"),
    );
  }
}
