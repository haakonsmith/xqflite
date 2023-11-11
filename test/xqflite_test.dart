import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:test/test.dart';

import 'package:xqflite/src/column.dart';
import 'package:xqflite/xqflite.dart';

final class Database extends XqfliteDatabase {
  Database._();

  static final Database _instance = Database._();
  static Database get instance => _instance;
}

class Artist {
  final String artistName;
  final int? artistId;

  const Artist({
    required this.artistName,
    this.artistId,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'artist_name': artistName,
      'artist_id': artistId,
    };
  }

  factory Artist.fromMap(Map<String, dynamic> map) {
    return Artist(
      artistName: map['artist_name'] as String,
      artistId: map['artist_id'] as int?,
    );
  }

  @override
  String toString() => 'Artist(artistName: $artistName, artistId: $artistId)';

  @override
  bool operator ==(covariant Artist other) {
    if (identical(this, other)) return true;

    return other.artistName == artistName && other.artistId == artistId;
  }

  @override
  int get hashCode => artistName.hashCode ^ artistId.hashCode;
}

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sql.sqfliteFfiInit();
  }
  // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
  // this step, it will use the sqlite version available on the system.
  sql.databaseFactory = sql.databaseFactoryFfi;

  group('Sql generation tests', () {
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

      expect(schema.tables['test']!.queryString(query), '''SELECT *
FROM test
WHERE
 test_col = 2
 test_col = 2''');
    });
  });

  group('actual db tests', () {
    test('double inner join', () async {
      final column = Column.text('test_col', nullable: true);
      final column2 = Column.integer('test_col2');

      final table = Table(columns: [column, column2], name: 'test');
      final table1 = Table(columns: [column, column2], name: 'test1');
      final table2 = Table(columns: [column, column2], name: 'test2');

      final schema = Schema([table, table1, table2]);

      await Database.instance.open(schema, dbPath: ":memory:");

      await Database.instance.schema.tables['test']!.toDbTable(Database.instance).insert({
        'test_col': '1',
        'test_col2': 1,
      });

      await Database.instance.schema.tables['test1']!.toDbTable(Database.instance).insert({
        'test_col': '1',
        'test_col2': 1,
      });

      await Database.instance.schema.tables['test2']!.toDbTable(Database.instance).insert({
        'test_col': '1',
        'test_col2': 1,
      });

      final queryResult = await Database.instance.schema.tables['test']! //
          .toDbTable(Database.instance)
          .innerJoin(Database.instance.schema.tables['test1']!.toDbTable(Database.instance), Query.equals('test.test_col', '1'))
          .innerJoin(Database.instance.schema.tables['test2']!.toDbTable(Database.instance), Query.equals('test.test_col', '1'))
          .query(Query.all());

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      expect(queryResult, [
        {'test_col': '1', 'test_col2': 1},
      ]);
    });

    test('query', () async {
      final column = Column.text('test_col', nullable: true);
      final column2 = Column.integer('test_col2');

      final table = Table(columns: [column, column2], name: 'test');

      final schema = Schema([table]);

      final query = Query([
        WhereClauseEquals(column.name, EqualityOperator.equals),
      ], [
        '2'
      ]);

      await Database.instance.open(schema, dbPath: ':memory:');

      await Database.instance.schema.tables['test']!.toDbTable(Database.instance).insert({
        'test_col': '2',
        'test_col2': 1,
      });

      final queryResult = await Database.instance.schema.tables['test']!.toDbTable(Database.instance).query(query);

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      print(queryResult);

      expect(queryResult, [
        {'test_col': '2', 'test_col2': 1}
      ]);
    });

    test('reference', () async {
      final artists = Table.builder('artists') //
          .text('artist_name')
          .primaryKey('artist_id')
          .build();

      final albums = Table.builder('albums') //
          .text('album_name')
          .primaryKey('album_id')
          .reference('artist_id', artists)
          .build();

      final schema = Schema([albums, artists]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final newArtistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bill',
      });

      await Database.instance.tables['albums']!.insert({
        'album_name': 'Music',
        'artist_id': newArtistId,
      });

      final result = await Database.instance.tables['albums']!.query(Query.all());

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      expect(result, [
        {'album_name': 'Music', 'album_id': 1, 'artist_id': 1}
      ]);
    });

    test('cascade reference', () async {
      final artists = Table.builder('artists') //
          .text('artist_name')
          .primaryKey('artist_id')
          .build();

      final albums = Table.builder('albums') //
          .text('album_name')
          .primaryKey('album_id')
          .reference('artist_id', artists, onDelete: CascadeOperation.setNull, nullable: true)
          .build();

      final schema = Schema([albums, artists], foreignkeys: true);

      await Database.instance.open(schema, dbPath: ':memory:');

      final newArtistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bill',
      });

      await Database.instance.tables['albums']!.insert({
        'album_name': 'Music',
        'artist_id': newArtistId,
      });

      await Database.instance.tables['artists']!.deleteId(newArtistId);

      final result = await Database.instance.tables['albums']!.query(Query.all());

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      print(result);

      expect(result, [
        {'album_name': 'Music', 'album_id': 1, 'artist_id': null}
      ]);
    });

    test('converter', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'Phill');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      await artists.insert(artist);

      final result = await artists.query(Query.all());

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      expect(result, [Artist(artistName: 'Phill', artistId: 1)]);
    });

    test('update', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'Phill');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      final artistId = await artists.insert(artist);
      await artists.updateId(Artist(artistName: "Brian", artistId: artistId), artistId);

      final result = await artists.query(Query.all());

      await Database.instance.close();
      await Database.instance.deleteDatabase();

      expect(result, [Artist(artistName: 'Brian', artistId: 1)]);
    });
  });
}
