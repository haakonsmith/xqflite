import 'package:collection/collection.dart';

enum EqualityOperator {
  equals('='),
  notEquals('!='),
  greaterThan('>'),
  greaterThanOrEqual('>='),
  lessThan('<'),
  lessThanOrEqual('<=');

  final String operand;

  const EqualityOperator(this.operand);
}

sealed class WhereClause {
  String get column;

  String toSql();
}

final class WhereClauseEquals implements WhereClause {
  final EqualityOperator equalityOperator;
  @override
  final String column;

  const WhereClauseEquals(this.column, this.equalityOperator);

  @override
  String toSql() => '$column ${equalityOperator.operand} ?';
}

/// A query without the values
final class PartialQuery {
  final List<WhereClause> whereClauses;

  bool get isAll => whereClauses.isEmpty;

  const PartialQuery(this.whereClauses);

  Query withValues(List<String> values) => Query(whereClauses, values);

  String whereString() => whereClauses.map((e) => e.toSql()).join(',\n');
  String? whereStringOrNull() => isAll ? null : whereString();
}

final class Query extends PartialQuery {
  final List<String> values;

  const Query(super.whereClauses, this.values);
  const Query.all()
      : values = const [],
        super(const []);
  static Query equals<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.equals)], [value.toString()]);

  static QueryBuilder builder() => QueryBuilder();

  List<String>? get valuesOrNull => isAll ? null : values;

  @override
  String whereString() => whereClauses.mapIndexed((i, e) => e.toSql().replaceFirst('?', values[i])).join(',\n');
}

final class QueryBuilder {
  final List<WhereClause> whereClauses = [];
  final List<String> values = [];

  QueryBuilder equals<T>(String column, T value) => this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.equals))
    ..values.add(value.toString());

  Query build() => Query(whereClauses, values);
}
