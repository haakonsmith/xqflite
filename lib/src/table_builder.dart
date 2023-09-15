import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/table.dart';

import 'data_types.dart';

final class TableBuilder {
  final String name;
  final List<Column> columns = [];

  TableBuilder(this.name);

  TableBuilder text(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.text, nullable: nullable));
  TableBuilder integer(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.integer, nullable: nullable));
  TableBuilder real(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.real, nullable: nullable));
  TableBuilder dateTime(String name, {bool nullable = false}) => this..columns.add(GenericColumn(name, DataType.dateTime, nullable: nullable));
  TableBuilder primaryKey(String name) => this..columns.add(PrimaryKeyColumn(name));
  TableBuilder reference(String name, Table table, {bool nullable = false}) => this..columns.add(ReferenceColumn(name, references: table, nullable: nullable));

  Table build() => Table(name: name, columns: columns);
}
