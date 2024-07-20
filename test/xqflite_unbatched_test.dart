import 'package:test/test.dart';

import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/exceptions.dart';
import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  group('un-batched db tests', () {
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

      final newArtistId = await Database.instance.getTable<int>('artists').insert({
        'artist_name': 'Bill',
      });

      await Database.instance.tables['albums']!.insert({
        'album_name': 'Music',
        'artist_id': newArtistId,
      });

      final result = await Database.instance.tables['albums']!.query(Query.all());

      await Database.instance.close();

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

      expect(result, [
        {'album_name': 'Music', 'album_id': 1, 'artist_id': null}
      ]);
    }, skip: true);

    test('converter', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'Phil');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      await artists.insert(artist);

      final result = await artists.query(Query.all());

      await Database.instance.close();

      expect(result, [Artist(artistName: 'Phil', artistId: 1)]);
    });

    test('update', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'Phil');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      final artistId = await artists.insert(artist);
      await artists.updateId(Artist(artistName: "Brian", artistId: artistId), artistId);

      final result = await artists.query(Query.all());

      await Database.instance.close();

      expect(result, [Artist(artistName: 'Brian', artistId: 1)]);
    });

    test('insert and query', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'John');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      final insertedArtistId = await artists.insert(artist);

      final result = await artists.query(Query.equals('artist_id', insertedArtistId));

      await Database.instance.close();

      expect(result, [Artist(artistName: 'John', artistId: insertedArtistId)]);
    });

    test('query with WHERE clause', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      await Database.instance.tables['artists']!.insert({'artist_name': 'John'});
      await Database.instance.tables['artists']!.insert({'artist_name': 'Jane'});
      await Database.instance.tables['artists']!.insert({'artist_name': 'Bob'});

      final queryResult = await Database.instance.tables['artists']!.query(Query.equals('artist_name', 'Jane'));

      await Database.instance.close();

      expect(queryResult, [
        {'artist_name': 'Jane', 'artist_id': 2}
      ]);
    });

    test('update', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'Phil');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      final artistId = await artists.insert(artist);

      final updatedArtist = Artist(artistName: 'Brian', artistId: artistId);
      await artists.updateId(updatedArtist, artistId);

      final result = await artists.query(Query.all());

      await Database.instance.close();

      expect(result, [updatedArtist]);
    });

    test('delete', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .primaryKey('artist_id') //
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artist = Artist(artistName: 'John');
      final artists = Database.instance.tables['artists']!.withConverter<Artist>((toDb: (artist) => artist.toMap(), fromDb: Artist.fromMap));

      final artistId = await artists.insert(artist);

      await artists.deleteId(artistId);

      final result = await artists.query(Query.all());

      await Database.instance.close();

      expect(result, []);
    });

    test('query with ORDER BY', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .integer('popularity') // Assume an artist has a popularity rating
          .primaryKey('artist_id')
          .build();

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      await Database.instance.tables['artists']!.insert({'artist_name': 'John', 'popularity': 5});
      await Database.instance.tables['artists']!.insert({'artist_name': 'Jane', 'popularity': 8});
      await Database.instance.tables['artists']!.insert({'artist_name': 'Bob', 'popularity': 3});

      final queryResult = await Database.instance.tables['artists']!.query(Query.builder().orderBy('popularity', direction: OrderByDirection.desc).build());

      await Database.instance.close();

      expect(queryResult, [
        {'artist_name': 'Jane', 'popularity': 8, 'artist_id': 2},
        {'artist_name': 'John', 'popularity': 5, 'artist_id': 1},
        {'artist_name': 'Bob', 'popularity': 3, 'artist_id': 3},
      ]);
    });

    test('insert with triggers', () async {
      final masterTable = Table.builder('master_table')
          .integer('row_id') // Assume an artist has a popularity rating
          .primaryKey('master_table_id')
          .build();

      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .integer('popularity') // Assume an artist has a popularity rating
          .primaryKey('artist_id')
          .trigger(
              (table) => """INSERT INTO master_table (row_id) VALUES
    (last_insert_rowid());""",
              name: "update_master_table",
              verb: TriggerVerb.insert,
              temporality: TriggerTemporality.after)
          .additionalSql((table) => """
CREATE TRIGGER IF NOT EXISTS update_master_table AFTER INSERT ON ${table.name}
BEGIN
  INSERT INTO master_table (row_id) VALUES
    (last_insert_rowid());
END;
          """)
          .build();

      final schema = Schema([artistsTable, masterTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bob',
        'popularity': 3,
      });
      final result = await Database.instance.tables["master_table"]!.query(Query.all());

      await Database.instance.close();

      expect(result, [
        {'row_id': artistId, 'master_table_id': 1}
      ]);
    });

    testDb('insert with abort', (db) async {
      await Database.instance.artists.insert(Artist(artistName: 'Artist', artistId: 1), conflictAlgorithm: ConflictAlgorithm.abort);

      await expectLater(Database.instance.artists.insert(Artist(artistName: 'Artist', artistId: 1), conflictAlgorithm: ConflictAlgorithm.abort),
          throwsA(isA<XqfliteGenericException>()));
    });

    testDb('insert with replace', (db) async {
      await Database.instance.artists.insert(Artist(artistName: 'Artist', artistId: 1), conflictAlgorithm: ConflictAlgorithm.replace);
      await Database.instance.artists.insert(Artist(artistName: 'Artist 2', artistId: 1), conflictAlgorithm: ConflictAlgorithm.replace);

      expect(await Database.instance.artists.queryId(1), Artist(artistName: 'Artist 2', artistId: 1));
    });

    test('insert with replace on unique column', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name', unique: true)
          .primaryKey('artist_id') //
          .build();

      await Database.instance.open(Schema([artistsTable]), dbPath: ':memory:');

      await Database.instance.artists.insert(Artist(artistName: 'Artist'), conflictAlgorithm: ConflictAlgorithm.replace);
      await Database.instance.artists.insert(Artist(artistName: 'Artist 2'), conflictAlgorithm: ConflictAlgorithm.replace);
      await Database.instance.artists.insert(Artist(artistName: 'Artist 2'), conflictAlgorithm: ConflictAlgorithm.replace);
      await Database.instance.artists.insert(Artist(artistName: 'Artist 2'), conflictAlgorithm: ConflictAlgorithm.replace);

      expect(await Database.instance.artists.query(Query.all()), [
        Artist(artistName: 'Artist', artistId: 1),
        Artist(artistName: 'Artist 2', artistId: 4),
      ]);

      await Database.instance.close();
    });

    test('insert string id', () async {
      final masterTable = Table.builder('master_table')
          .integer('row_id') // Assume an artist has a popularity rating
          .primaryKey('master_table_id')
          .build(withoutRowId: true);

      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .integer('popularity') // Assume an artist has a popularity rating
          .primaryKeyCuid('artist_id')
          .build(withoutRowId: true);

      final schema = Schema([artistsTable, masterTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bob',
        'popularity': 3,
      });

      final result = await Database.instance.tables['artists']!.query(Query.all());

      await Database.instance.close();

      expect(result, [
        {'artist_name': 'Bob', 'popularity': 3, 'artist_id': artistId}
      ]);
    });

    test('insert with null value', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .integer('popularity', nullable: true) // Assume an artist has a popularity rating
          .primaryKeyCuid('artist_id')
          .build(withoutRowId: true);

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bob',
        'popularity': null,
      });

      final result = await Database.instance.tables['artists']!.query(Query.all());

      await Database.instance.close();

      expect(result, [
        {'artist_name': 'Bob', 'popularity': null, 'artist_id': artistId}
      ]);
    });

    test('update with null value', () async {
      final artistsTable = Table.builder('artists')
          .text('artist_name')
          .integer('popularity', nullable: true) // Assume an artist has a popularity rating
          .primaryKeyCuid('artist_id')
          .build(withoutRowId: true);

      final schema = Schema([artistsTable]);

      await Database.instance.open(schema, dbPath: ':memory:');

      final artistId = await Database.instance.tables['artists']!.insert({
        'artist_name': 'Bob',
        'popularity': 12,
      });

      await Database.instance.tables['artists']!.updateId({'popularity': null}, artistId);

      final result = await Database.instance.tables['artists']!.query(Query.all());

      await Database.instance.close();

      expect(result, [
        {'artist_name': 'Bob', 'popularity': null, 'artist_id': artistId}
      ]);
    });
  });
}
