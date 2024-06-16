import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/table.dart';

import 'data_types.dart';

final class TableBuilder {
  final String name;
  final List<Column> columns = [];

  TableBuilder(this.name);

  TableBuilder text(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.text, nullable: nullable));
  TableBuilder integer(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.integer, nullable: nullable));
  TableBuilder bytes(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.bytes, nullable: nullable));
  TableBuilder real(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.real, nullable: nullable));
  TableBuilder boolean(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.boolean, nullable: nullable));

  TableBuilder dateTime(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.dateTime, nullable: nullable));
  TableBuilder primaryKey(String name) => this..columns.add(PrimaryKeyColumn(name));
  TableBuilder primaryKeyCuid(String name) => this..columns.add(PrimaryKeyCuidColumn(name));
  TableBuilder primaryKeyUuid(String name) => this..columns.add(PrimaryKeyUuidColumn(name));
  TableBuilder reference(String name, Table table, {bool nullable = false, CascadeOperation? onUpdate, CascadeOperation? onDelete}) =>
      this..columns.add(ReferenceColumn(name, references: table, nullable: nullable, onDelete: onDelete, onUpdate: onUpdate));

  Table build() => Table(name: name, columns: columns, childJoins: []);
}
