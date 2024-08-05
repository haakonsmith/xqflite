import 'package:test/test.dart';

import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  group('xqflite queries numbers', () {
    testDb('group', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.builder()
            .equals('artist_id', 1)
            .or()
            .group((q) => q.equals('artist_id', 2))
            .or()
            .group((q) => q.equals('artist_id', 3))
            .build()),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2),
          Artist(artistName: 'test3', artistId: 3),
        ],
      );
    });

    testDb('between', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists
            .query(Query.builder().between('artist_id', 0, 2).build()),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2),
        ],
      );
    });

    testDb('conjuction', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.builder()
            .greaterThan('artist_id', 0)
            .and()
            .lessThan('artist_id', 3)
            .build()),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2),
        ],
      );
    });

    testDb('disjunction', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.builder()
            .equals('artist_id', 1)
            .or()
            .equals('artist_id', 2)
            .build()),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2),
        ],
      );
    });

    testDb('equals with numbers', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.equals('artist_id', 2)),
        [Artist(artistName: 'test2', artistId: 2)],
      );
    });

    testDb('notEquals with numbers', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.notEquals('artist_id', 2)),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });
  });

  group('xqflite queries string', () {
    testDb('innerJoin', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.albums.insert(Album(albumName: 'album1', artistId: 1));
      await database.albums.insert(Album(albumName: 'album2', artistId: 1));

      final result = await database.artists
          .innerJoin(database.albums,
              Query.equals('artists.artist_id', 'albums.artist_id'))
          .query(Query.all());

      expect(result, [
        // Album(albumName: 'album1', artistId: 1),
        // Album(albumName: 'album2', artistId: 1),
        {
          'artist_name': 'test',
          'artist_id': 1,
          'album_name': 'album1',
          'album_id': 1
        },
        {
          'artist_name': 'test',
          'artist_id': 1,
          'album_name': 'album2',
          'album_id': 2
        }
      ]);
    });

    testDb('specific columns', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));

      expect(
        await database.artists.table.query(Query.builder(['artist_name'])
            .equals('artist_name', 'test2')
            .build()),
        [
          {'artist_name': 'test2'}
        ],
      );
    });

    testDb('distinct', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));

      expect(
        await database.artists.table
            .query(Query.builder(['artist_name']).distinct().build()),
        [
          {'artist_name': 'test'},
          {'artist_name': 'test2'}
        ],
      );
    });

    testDb('equals', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));
      await database.artists.insert(Artist(artistName: 'test3'));

      expect(
        await database.artists.query(Query.equals('artist_name', 'test2')),
        [Artist(artistName: 'test2', artistId: 2)],
      );
    });

    testDb('notEquals', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));
      await database.artists.insert(Artist(artistName: 'test3'));

      expect(
        await database.artists.query(Query.notEquals('artist_name', 'test2')),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });

    testDb('greaterThan', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.greaterThan('artist_id', 1)),
        [
          Artist(artistName: 'test2', artistId: 2),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });

    testDb('lessThan', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.lessThan('artist_id', 3)),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2)
        ],
      );
    });

    testDb('greaterThanOrEquals', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.greaterThanOrEqual('artist_id', 2)),
        [
          Artist(artistName: 'test2', artistId: 2),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });

    testDb('lessThanOrEquals', (database) async {
      await database.artists.insert(Artist(artistName: 'test', artistId: 1));
      await database.artists.insert(Artist(artistName: 'test2', artistId: 2));
      await database.artists.insert(Artist(artistName: 'test3', artistId: 3));

      expect(
        await database.artists.query(Query.lessThanOrEqual('artist_id', 2)),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2)
        ],
      );
    });

    testDb('inList', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));
      await database.artists.insert(Artist(artistName: 'test3'));

      expect(
        await database.artists
            .query(Query.inList('artist_name', ['test', 'test3'])),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });

    testDb('like', (database) async {
      await database.artists.insert(Artist(artistName: 'test'));
      await database.artists.insert(Artist(artistName: 'test2'));
      await database.artists.insert(Artist(artistName: 'test3'));

      expect(
        await database.artists.query(Query.like('artist_name', '%test%')),
        [
          Artist(artistName: 'test', artistId: 1),
          Artist(artistName: 'test2', artistId: 2),
          Artist(artistName: 'test3', artistId: 3)
        ],
      );
    });
  });
}
