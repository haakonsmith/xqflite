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

sealed class Join {
  final Query on;
  final Table joinee;

  const Join({required this.on, required this.joinee});

  String toSql();
}

final class InnerJoin extends Join {
  const InnerJoin({required super.on, required super.joinee});

  @override
  String toSql() => "INNER JOIN ${joinee.tableName} ON ${on.whereStringWithValues()}";
}

class Table<KeyType> {
  final String name;
  final List<Column> columns;
  final PrimaryKey primaryKey;
  final List<String> groupProperties;
  final List<Join> childJoins;
  final String additionalSql;
  final bool withoutRowId;

  Table({
    required this.columns,
    required this.name,
    this.childJoins = const [],
    this.groupProperties = const [],
    this.additionalSql = "",
    this.withoutRowId = false,
  }) : primaryKey = columns.whereType<IntoPrimaryKey>().firstOrNull?.toKey() ?? RowIdKey() {
    switch (primaryKey) {
      case SingleColumnKey primaryKey:
        assert(columns.contains(primaryKey.column), 'Single Primary key must be subset of columns');
        break;
      default:
    }
  }

  factory Table.columns(String name, List<Column> columns, [List<Join> childJoins = const []]) {
    return Table(columns: columns, name: name, childJoins: childJoins);
  }

  static TableBuilder builder(String name) {
    return TableBuilder(name);
  }

  bool get hasReferences => columns.any((column) => column is ReferenceColumn);

  DbTable<KeyType> toDbTable(XqfliteDatabase database) => DbTable(database, this);
  Table innerJoin<T extends Table>(T joinee, Query on) =>
      Table(columns: columns, name: name, groupProperties: groupProperties, childJoins: [...childJoins, InnerJoin(on: on, joinee: joinee)]);

  Table groupBy(List<String> groupProperties) => Table(columns: columns, name: name, groupProperties: groupProperties, childJoins: childJoins);

  String toSql() {
    return '''
      CREATE TABLE IF NOT EXISTS $name (
${columns.map((e) => '        ${e.toSql()}').join(",\n")}
      )${withoutRowId ? ' WITHOUT ROWID' : ''};

$additionalSql
      ''';
  }

  String get tableName => name;

  String tableIdQuery() {
    final buffer = StringBuffer('$tableName\n');

    for (final join in childJoins) {
      buffer.writeln(join.toSql());
    }

    return buffer.toString();
  }

  String queryString(Query query) {
    final buffer = StringBuffer('SELECT * FROM $tableName\n');

    for (final join in childJoins) {
      buffer.writeln(join.toSql());
    }

    if (query.whereClauses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("WHERE");
      buffer.writeln(query.whereStringWithValues());
    }

    if (query.orderByClauses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln("ORDER BY");
      buffer.writeln(query.orderByString());
    }

    // if (hasReferences) {
    //   buffer.writeln();
    //   buffer.writeln(buildInnerJoins(this));
    // }

    return buffer.toString().trim();
  }

  /// This builds an insert statement
  /// It takes in the values as a list to assert the order. If not provided order cannot be guaranteed
  String buildInsertStatement({Iterable<String>? columnNames, ConflictAlgorithm onConflict = ConflictAlgorithm.abort}) {
    final buffer = StringBuffer('INSERT OR ${onConflict.name} INTO $tableName\n');

    buffer.write("(");
    buffer.write((columnNames ?? columns.map((e) => e.name)).join(", "));
    buffer.writeln(")");

    buffer.write("VALUES (");
    buffer.write((columnNames?.map((e) => "?") ?? columns.map((e) => "?")).join(", "));
    buffer.writeln(")");

    buffer.write("RETURNING ${primaryKey.toSqlList()}");

    return buffer.toString();
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
