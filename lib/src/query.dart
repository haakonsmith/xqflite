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

enum BooleanOperator {
  and('and'),
  or('and'),
  inital('');

  final String sql;

  const BooleanOperator(this.sql);
}

sealed class WhereClause {
  final BooleanOperator operator;
  final String column;

  const WhereClause(this.column, this.operator);

  String toSql();
  WhereClause copyWith({BooleanOperator? operator, String? column});
  // return WhereClause(operator?? this.operator, column ?? this.column,);
  // }
}

final class WhereClauseEquals implements WhereClause {
  final EqualityOperator equalityOperator;

  @override
  final String column;

  @override
  final BooleanOperator operator;

  const WhereClauseEquals(
    this.column,
    this.equalityOperator, {
    this.operator = BooleanOperator.inital,
  });

  @override
  String toSql() => '${operator.sql} $column ${equalityOperator.operand} ?';

  @override
  WhereClauseEquals copyWith({
    BooleanOperator? operator,
    String? column,
  }) {
    return WhereClauseEquals(
      column ?? this.column,
      equalityOperator,
      operator: operator ?? this.operator,
    );
  }
}

final class WhereClauseContains implements WhereClause {
  @override
  final BooleanOperator operator;

  @override
  final String column;

  const WhereClauseContains(this.column, {this.operator = BooleanOperator.inital});

  @override
  String toSql() => '${operator.sql} $column LIKE "%?%"';

  @override
  WhereClauseContains copyWith({
    BooleanOperator? operator,
    String? column,
  }) {
    return WhereClauseContains(
      column ?? this.column,
      operator: operator ?? this.operator,
    );
  }
}

final class WhereClauseIn implements WhereClause {
  @override
  final BooleanOperator operator;

  @override
  final String column;

  final int count;

  const WhereClauseIn(this.column, this.count, {this.operator = BooleanOperator.inital});

  @override
  String toSql() => '${operator.sql} $column IN (${List.generate(count, (index) => "?").join(', ')})';

  @override
  WhereClauseContains copyWith({
    BooleanOperator? operator,
    String? column,
  }) {
    return WhereClauseContains(
      column ?? this.column,
      operator: operator ?? this.operator,
    );
  }
}

enum OrderByDirection { asc, desc }

final class OrderByClause {
  const OrderByClause({
    required this.columnName,
    this.nullsLast = false,
    this.direction = OrderByDirection.asc,
  });

  final String columnName;
  final bool nullsLast;
  final OrderByDirection direction;

  String toSql() => '$columnName ${direction.name.toUpperCase()}${nullsLast ? ", NULLS LAST" : ""}';
}

/// A query without the values
final class PartialQuery {
  final List<WhereClause> whereClauses;
  final List<OrderByClause> orderByClauses;

  bool get isAll => whereClauses.isEmpty;

  const PartialQuery(this.whereClauses, [this.orderByClauses = const []]);

  Query withValues(List<String> values) => Query(whereClauses, values, orderByClauses);

  String orderByString() => orderByClauses.isNotEmpty ? "${orderByClauses.map((e) => e.toSql()).join('\n')}" : '';
  String whereString() => whereClauses.map((e) => e.toSql()).join('\n');
  String? whereStringOrNull() => isAll ? null : whereString();
}

final class Query extends PartialQuery {
  final List<String> values;

  const Query(super.whereClauses, this.values, [super.orderByClauses = const []]);
  const Query.all()
      : values = const [],
        super(const []);
  static Query equals<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.equals)], [value.toString()]);
  static Query notEquals<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.notEquals)], [value.toString()]);

  static Query contains<T>(String column, T value) => Query([WhereClauseContains(column)], [value.toString()]);

  /// Actually does what you'd expect, the above is for direct use
  static Query inList<T>(String column, List<T> value) => Query([WhereClauseIn(column, value.length)], [...value.map((e) => e.toString())]);

  static Query greaterThan<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.greaterThan)], [value.toString()]);
  static Query greaterThanOrEqual<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.greaterThanOrEqual)], [value.toString()]);
  static Query lessThan<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.lessThan)], [value.toString()]);
  static Query lessThanOrEqual<T>(String column, T value) => Query([WhereClauseEquals(column, EqualityOperator.lessThanOrEqual)], [value.toString()]);

  static QueryBuilder builder() => QueryBuilder();

  List<String>? get valuesOrNull => isAll ? null : values;

  String whereStringWithValues() => whereClauses.mapIndexed((i, e) => e.toSql().replaceAll('?', values[i])).join('\n');
}

final class QueryOperatorBuilder {
  final QueryBuilder builder;

  const QueryOperatorBuilder(this.builder);

  QueryBuilder and() => builder..operators.add(BooleanOperator.and);
  QueryBuilder or() => builder..operators.add(BooleanOperator.or);
  QueryOperatorBuilder orderBy(String column, {OrderByDirection direction = OrderByDirection.asc, bool nullsLast = false}) =>
      this..builder.orderBy(column, direction: direction, nullsLast: nullsLast);

  Query build() => builder.build();
}

final class QueryBuilder {
  final List<BooleanOperator> operators;
  final List<WhereClause> whereClauses;
  final List<OrderByClause> orderByClauses;
  final List<String> values;

  QueryBuilder()
      : orderByClauses = [],
        whereClauses = [],
        operators = [],
        values = [];

  QueryOperatorBuilder equals<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.equals))
    ..values.add(value.toString()));

  QueryOperatorBuilder notEquals<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.notEquals))
    ..values.add(value.toString()));

  QueryOperatorBuilder greaterThan<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.greaterThan))
    ..values.add(value.toString()));

  QueryOperatorBuilder greaterThanOrEqual<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.greaterThanOrEqual))
    ..values.add(value.toString()));

  QueryOperatorBuilder lessThan<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.lessThan))
    ..values.add(value.toString()));

  QueryOperatorBuilder lessThanOrEqual<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.lessThanOrEqual))
    ..values.add(value.toString()));

  QueryBuilder orderBy(String column, {OrderByDirection direction = OrderByDirection.asc, bool nullsLast = false}) =>
      this..orderByClauses.add(OrderByClause(columnName: column, direction: direction, nullsLast: nullsLast));

  Query build() {
    for (var i = 0; i < whereClauses.length - 1; i++) {
      if (i > whereClauses.length - 1) break;

      whereClauses[i + 1] = whereClauses[i + 1].copyWith(operator: operators[i]);
    }

    return Query(
      whereClauses,
      values,
      orderByClauses,
    );
  }
}
