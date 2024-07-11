import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/table.dart';
import 'package:xqflite/src/utils.dart';

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

final class TableBuilder {
  final String tableName;
  final List<String Function(Table table)> sqlBuilders = [];
  final List<Column> columns = [];

  TableBuilder(this.tableName);

  TableBuilder text(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.text, nullable: nullable));
  TableBuilder integer(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.integer, nullable: nullable));
  TableBuilder bytes(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.bytes, nullable: nullable));
  TableBuilder real(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.real, nullable: nullable));
  TableBuilder boolean(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.boolean, nullable: nullable));

  TableBuilder dateTime(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.dateTime, nullable: nullable));
  TableBuilder primaryKey(String name) => this..columns.add(PrimaryKeyColumn(name));
  TableBuilder primaryKeyCuid(String name) => this..columns.add(PrimaryKeyCuidColumn(name));
  TableBuilder primaryKeyUuid(String name) => this..columns.add(PrimaryKeyUuidColumn(name));
  TableBuilder reference(String name, Table table,
          {bool nullable = false, CascadeOperation? onUpdate, CascadeOperation? onDelete, DataAffinity type = DataAffinity.integer}) =>
      this..columns.add(ReferenceColumn(name, references: table, nullable: nullable, onDelete: onDelete, onUpdate: onUpdate, type: type));

  /// This additional sql will get executed immediately after table creation,
  /// This is useful for triggers, keep in mind all triggers written like this should have "IF NOT EXISTS" as the will get executed regardless
  /// Initalisation of this property is deffered so it will always have all columns within it.
  TableBuilder additionalSql(String Function(Table table) sql) => this..sqlBuilders.add(sql);

  TableBuilder trigger(
    String Function(Table table) sql, {
    required String name,
    required TriggerVerb verb,
    TriggerTemporality temporality = TriggerTemporality.before,
  }) =>
      this..sqlBuilders.add((table) => TriggerBuilder(table.name, name, verb: verb, temporality: temporality).sql(sql(table)));

  /// D
  Table<Key> build<Key>({bool withoutRowId = false}) {
    final table = Table(name: tableName, columns: columns);

    // assert(Key != dynamic, "Hi, sorry. I wish I could've told you this sooner (at compile time), but here we are.\nIt's not me it's you, you've passed in the wrong type... Sorry...\nBasically, just give me a concrete type here and all will be well");

    return Table<Key>(
      name: tableName,
      columns: columns,
      childJoins: [],
      withoutRowId: withoutRowId,
      additionalSql: sqlBuilders.map((f) => f(table)).join("\n"),
    );
  }
}
