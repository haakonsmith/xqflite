import 'package:xqflite/src/table.dart';

class Schema {
  final Map<String, Table> tables;

  Schema(List<Table> tables) : tables = Map.fromEntries(tables.map((e) => MapEntry(e.name, e)));
}
