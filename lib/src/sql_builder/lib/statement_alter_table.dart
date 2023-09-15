part of 'statement.dart';

sealed class AlterTableToken extends Token {
  const AlterTableToken();
}

final class AlterTableRenameTable extends AlterTableToken {
  final String newTableName;

  const AlterTableRenameTable(this.newTableName);

  @override
  String get value => 'TO $newTableName';
}

final class AlterTableRenameColumn extends AlterTableToken {
  final String oldColumnName;
  final String newColumnName;

  const AlterTableRenameColumn(this.oldColumnName, this.newColumnName);

  @override
  String get value => 'COLUMN $oldColumnName TO $newColumnName';
}

final class AlterTableAddColumn extends AlterTableToken {
  final Column column;

  const AlterTableAddColumn(this.column);

  @override
  String get value => 'ADD ${column.toSql()}';
}

final class AlterTableDrop extends AlterTableToken {
  final String columnName;

  const AlterTableDrop(this.columnName);

  @override
  String get value => 'DROP COLUMN $columnName';
}

/// https://www.sqlite.org/syntaxdiagrams.html#alter-table-stmt
final class StatementAlterTable extends Statement {
  final String tableName;
  final AlterTableToken token;

  const StatementAlterTable(this.tableName, this.token);

  @override
  String get value => 'ALTER TABLE $tableName\n${token.value}';
}

class AlterTableBuilder {
  final StatementBuilder builder;
  final String tableName;

  const AlterTableBuilder(this.builder, this.tableName);

  StatementBuilder drop(String columnName) => builder..statements.add(StatementAlterTable(tableName, AlterTableDrop(columnName)));
  StatementBuilder add(Column column) => builder..statements.add(StatementAlterTable(tableName, AlterTableAddColumn(column)));
  StatementBuilder rename(String newTableName) => builder..statements.add(StatementAlterTable(tableName, AlterTableRenameTable(newTableName)));
  StatementBuilder renameColumn(String oldColumnName, String newColumnName) =>
      builder..statements.add(StatementAlterTable(tableName, AlterTableRenameColumn(oldColumnName, newColumnName)));
}

extension AlterTable on StatementBuilder {
  AlterTableBuilder alterTable(String tableName) => AlterTableBuilder(this, tableName);
}
