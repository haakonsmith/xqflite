import 'package:collection/collection.dart';
import 'package:xqflite/src/column.dart';
import 'package:xqflite/xqflite.dart';
import 'package:xqflite/src/table_builder.dart';

typedef Converter<T> = ({
  T Function(RawData data) fromDb,
  RawData Function(T data) toDb,
});
typedef RawData = Map<String, Object?>;

extension TryConverter<T> on Converter<T>? {
  Converter<T> getExcept<Q>(Table table) {
    if (this == null) throw Exception('Missing converter on $table for type $Q.');

    return this!;
  }
}

sealed class PrimaryKey {
  const PrimaryKey();

  /// Returns a list for this command
  ///
  /// REFERENCES table_name(${toSqlList()})
  String toSqlList();

  PartialQuery get query;
}

final class RowIdKey extends PrimaryKey {
  @override
  String toSqlList() => 'Rowid';

  @override
  PartialQuery get query => PartialQuery([WhereClauseEquals('Rowid', EqualityOperator.equals)]);
}

final class SingleColumnKey extends PrimaryKey {
  final Column column;

  const SingleColumnKey(this.column);

  @override
  String toSqlList() => column.name;

  @override
  PartialQuery get query => PartialQuery([WhereClauseEquals(column.name, EqualityOperator.equals)]);
}

class Table {
  final String name;
  final List<Column> columns;
  final PrimaryKey primaryKey;
  final List<String> groupProperties;

  Table({
    required this.columns,
    required this.name,
    this.groupProperties = const [],
  }) : primaryKey = columns.whereType<PrimaryKeyColumn>().firstOrNull?.toKey() ?? RowIdKey() {
    switch (primaryKey) {
      case SingleColumnKey primaryKey:
        assert(columns.contains(primaryKey.column), 'Single Primary key must be subset of columns');
        break;
      default:
    }
  }

  factory Table.columns(String name, List<Column> columns) {
    return Table(columns: columns, name: name);
  }

  static TableBuilder builder(String name) {
    return TableBuilder(name);
  }

  bool get hasReferences => columns.any((column) => column is ReferenceColumn);

  DbTable toDbTable(XqfliteDatabase database) => DbTable(database, this);
  InnerJoinTable innerJoin(Table joinee, Query on) => InnerJoinTable(
        columns: columns,
        on: on,
        joinee: joinee,
        name: name,
      );

  Table groupBy(List<String> groupProperties) => Table(columns: columns, name: name, groupProperties: groupProperties);

  String toSql() {
    return '''
      CREATE TABLE IF NOT EXISTS $name (
${columns.map((e) => '        ${e.toSql()}').join(",\n")}
      );
      ''';
  }

  String queryString(Query query) {
    final buffer = StringBuffer('SELECT *\nFROM $name');

    if (query.whereClauses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("WHERE");
      buffer.writeln(query.whereStringWithValues());
    }

    // if (hasReferences) {
    //   buffer.writeln();
    //   buffer.writeln(buildInnerJoins(this));
    // }

    return buffer.toString().trim();
  }

  String buildInnerJoins(Table parentTable) {
    final buffer = StringBuffer();
    final columns = parentTable.columns;

    for (final column in columns.whereType<ReferenceColumn>()) {
      final table = column.references;

      buffer.writeln(switch (table.primaryKey) {
        SingleColumnKey primaryKey => 'INNER JOIN ${table.name} ON ${table.name}.${primaryKey.column.name} = ${parentTable.name}.${column.name}',
        RowIdKey _ => 'INNER JOIN ${table.name} ON ${table.name}.Rowid = ${parentTable.name}.${column.name}',
      });

      if (table.hasReferences) buffer.writeln(buildInnerJoins(table));
    }

    return buffer.toString();
  }
}

class InnerJoinTable extends Table {
  InnerJoinTable({
    required super.columns,
    required super.name,
    required this.on,
    required this.joinee,
  });

  final Query on;
  final Table joinee;

  @override
  String queryString(Query query) {
    final buffer = StringBuffer('SELECT *\nFROM $name ');

    buffer.writeln("INNER JOIN ${joinee.name} ON ${on.whereStringWithValues()}");

    if (query.whereClauses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("WHERE");
      buffer.writeln(query.whereStringWithValues());
    }

    return buffer.toString().trim();
  }
}
