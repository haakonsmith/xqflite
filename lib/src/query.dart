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
  static Query contains<T>(String column, T value) => Query([WhereClauseContains(column)], [value.toString()]);

  static QueryBuilder builder() => QueryBuilder();

  List<String>? get valuesOrNull => isAll ? null : values;

  @override
  String whereString() => whereClauses.mapIndexed((i, e) => e.toSql().replaceFirst('?', values[i])).join('\n');
}

final class QueryOperatorBuilder {
  final QueryBuilder builder;

  const QueryOperatorBuilder(this.builder);

  QueryBuilder and() => builder..operators.add(BooleanOperator.and);
  QueryBuilder or() => builder..operators.add(BooleanOperator.or);

  Query build() => builder.build();
}

final class QueryBuilder {
  final List<BooleanOperator> operators;
  final List<WhereClause> whereClauses;
  final List<String> values;

  QueryBuilder()
      : whereClauses = [],
        operators = [],
        values = [];

  QueryOperatorBuilder equals<T>(String column, T value) => QueryOperatorBuilder(this
    ..whereClauses.add(WhereClauseEquals(column, EqualityOperator.equals))
    ..values.add(value.toString()));

  Query build() {
    for (var i = 0; i < whereClauses.length - 1; i++) {
      if (i > whereClauses.length - 1) break;

      whereClauses[i + 1] = whereClauses[i + 1].copyWith(operator: operators[i]);
    }

    return Query(whereClauses, values);
  }
}
//
// final class JoinQuery extends PartialQuery {
//
//   const JoinQuery(super.whereClauses, this.values);
// }
