import 'package:test/test.dart';
import 'package:xqflite/src/column.dart';
import 'package:xqflite/xqflite.dart';

void main() {
  group('sql generation tests', () {
    test('Basic db construction', () async {
      final column = Column.text('test_col');

      final schema = Schema([
        Table(columns: [column], name: 'test'),
      ]);

      expect(schema.tables['test']!.toSql().trim(), '''CREATE TABLE IF NOT EXISTS test (
        test_col TEXT NOT NULL
      );''');
    });

    test('Basic db construction 2', () async {
      final column = Column.text('test_col');
      final column2 = Column.integer('test_col2');

      final schema = Schema([
        Table(columns: [column, column2], name: 'test'),
      ]);

      expect(schema.tables['test']!.toSql().trim(), '''CREATE TABLE IF NOT EXISTS test (
        test_col TEXT NOT NULL,
        test_col2 INTEGER NOT NULL
      );''');
    });

    test('Basic db construction 3', () async {
      final column = Column.text('test_col', nullable: true);
      final column2 = Column.integer('test_col2');

      final schema = Schema([
        Table(columns: [column, column2], name: 'test'),
      ]);

      expect(schema.tables['test']!.toSql().trim(), '''CREATE TABLE IF NOT EXISTS test (
        test_col TEXT,
        test_col2 INTEGER NOT NULL
      );''');
    });

    test('Basic query construction', () async {
      final column = Column.text('test_col', nullable: true);
      final column2 = Column.integer('test_col2');

      final schema = Schema([
        Table(columns: [column, column2], name: 'test'),
      ]);

      final query = Query([
        WhereClauseEquals(column.name, EqualityOperator.equals),
        WhereClauseEquals(column.name, EqualityOperator.equals),
      ], [
        '2',
        '2'
      ]);

      expect(schema.tables['test']!.queryString(query), '''SELECT * FROM test

WHERE
 test_col = 2
 test_col = 2''');
    });
  });
}
