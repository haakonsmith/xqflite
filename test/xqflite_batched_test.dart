import 'package:test/test.dart';

import 'package:xqflite/src/column.dart';
import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  group('batched db tests', () {
    test('double inner join', () async {
      final column = Column.text('test_col', nullable: true);
      final column2 = Column.integer('test_col2');

      final table = Table(columns: [column, column2], name: 'test');
      final table1 = Table(columns: [column, column2], name: 'test1');
      final table2 = Table(columns: [column, column2], name: 'test2');

      final schema = Schema([table, table1, table2]);

      await Database.instance.open(schema, dbPath: ":memory:");

      await Database.instance.batch((batch) {
        batch.withTable(schema.tables['test']!).insert({
          'test_col': '1',
          'test_col2': 1,
        });

        batch.withTable(schema.tables['test1']!).insert({
          'test_col': '1',
          'test_col2': 1,
        });

        batch.withTable(schema.tables['test2']!).insert({
          'test_col': '1',
          'test_col2': 1,
        });
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

      expect(result, [
        {'album_name': 'Music', 'album_id': 1, 'artist_id': 1}
      ]);
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

      await artists.batch((batch) {
        batch.updateId(Artist(artistName: "Brian", artistId: artistId), artistId);
      });

      final result = await artists.query(Query.all());

      await Database.instance.close();

      expect(result, [Artist(artistName: 'Brian', artistId: 1)]);
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

      await artists.batch((batch) {
        batch.deleteId(artistId);
      });

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

      await Database.instance.tables['artists']!.batch((batch) {
        batch.insert({'artist_name': 'John', 'popularity': 5});
        batch.insert({'artist_name': 'Jane', 'popularity': 8});
        batch.insert({'artist_name': 'Bob', 'popularity': 3});
      });

      final queryResult = await Database.instance.tables['artists']!.query(Query.builder().orderBy('popularity', direction: OrderByDirection.desc).build());

      await Database.instance.close();

      expect(queryResult, [
        {'artist_name': 'Jane', 'popularity': 8, 'artist_id': 2},
        {'artist_name': 'John', 'popularity': 5, 'artist_id': 1},
        {'artist_name': 'Bob', 'popularity': 3, 'artist_id': 3},
      ]);
    });
  });
}
