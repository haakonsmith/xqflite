import 'package:xqflite/src/table.dart';

class Schema {
  final Map<String, Table> tables;

  /// https://www.sqlite.org/foreignkeys.html
  final bool foreignkeys;

  Schema(List<Table> tables, {this.foreignkeys = false}) : tables = Map.fromEntries(tables.map((e) => MapEntry(e.name, e)));
}
