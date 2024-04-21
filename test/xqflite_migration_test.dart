import 'package:test/test.dart';
import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  group('migrations', () {
    testDb(
      'migration from version',
      (database) async {
        await database.artists.table.insert({'artist_name': 'test', 'artist_id': 1, 'artist_age': '20'});
        await database.albums.insert(Album(albumName: 'album1', artistId: 1));
        await database.albums.insert(Album(albumName: 'album2', artistId: 1));

        final result = await database.artists.innerJoin(database.albums, Query.equals('artists.artist_id', 'albums.artist_id')).query(Query.all());

        expect(result, [
          {'artist_name': 'test', 'artist_id': 1, 'album_name': 'album1', 'album_id': 1, 'artist_age': '20'},
          {'artist_name': 'test', 'artist_id': 1, 'album_name': 'album2', 'album_id': 2, 'artist_age': '20'}
        ]);
      },
      migrations: [
        Migration(
          version: 0,
          migrator: (db, version) async {
            await db.execute('ALTER TABLE artists ADD COLUMN artist_age TEXT');
          },
        )
      ],
      initialVersion: 0,
    );

    test('migration with invalid migration path', () async {
      await expectLater(
        () async => Database.instance.open(
          Schema([], migrations: [Migration(version: 1, migrator: (db, version) async {})]),
          dbPath: ':memory:',
          onBeforeMigration: (db) => db.execute('PRAGMA user_version = 1'),
        ),
        throwsA(isA<MigrationMissingError>()),
      );
    });

    test('migration with initial version of 0', () async {
      await Database.instance.open(
        Schema([], migrations: [
          Migration(
              version: 0,
              migrator: (db, version) async {
                throw Exception("This shouldn't run!");
              })
        ]),
        dbPath: ':memory:',
        nukeDb: true,
        onBeforeMigration: (db) => db.execute('PRAGMA foreign_keys = 1'),
      );
    });
  });
}
