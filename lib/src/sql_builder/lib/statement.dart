import 'package:xqflite/src/column.dart';

part 'statement_alter_table.dart';

abstract base class Token {
  String get value;

  const Token();
}

/// https://sqlite.org/lang.html
sealed class Statement {
  const Statement();

  String get value;
}

class StatementBuilder {
  final List<Statement> statements = [];

  String toSql() {
    return statements.map((e) => e.value).join(' ');
  }
}
