import 'package:xqflite/src/migration.dart';
import 'package:xqflite/src/table.dart';

class Schema {
  final Map<String, Table> tables;

  /// https://www.sqlite.org/foreignkeys.html
  final bool foreignkeys;

  /// This is a list of migrations that will be run when the database is opened.
  /// The order does not matter, they will be sorted by version.
  final List<Migration> migrations;

  Schema(
    List<Table> tables, {
    this.foreignkeys = false,
    this.migrations = const [],
  }) : tables = Map.fromEntries(tables.map((e) => MapEntry(e.name, e))) {
    final versions = migrations.map((e) => e.version).toSet();
    assert(versions.length == migrations.length, 'There are duplicate versions in the migrations. This is not allowed. Please remove the duplicates.');
  }
}
