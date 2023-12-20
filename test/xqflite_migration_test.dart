import 'package:test/test.dart';
import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  group('migrations', () {
    testDb('innerJoin', (database) async {
      await database.artists.table.insert({'artist_name': 'test', 'artist_id': 1, 'artist_age': '20'});
      await database.albums.insert(Album(albumName: 'album1', artistId: 1));
      await database.albums.insert(Album(albumName: 'album2', artistId: 1));

      final result = await database.artists.innerJoin(database.albums, Query.equals('artists.artist_id', 'albums.artist_id')).query(Query.all());

      print(result);

      expect(result, [
        {'artist_name': 'test', 'artist_id': 1, 'album_name': 'album1', 'album_id': 1, 'artist_age': '20'},
        {'artist_name': 'test', 'artist_id': 1, 'album_name': 'album2', 'album_id': 2, 'artist_age': '20'}
      ]);
    }, migrations: [
      (db, version) async {
        db.execute('ALTER TABLE artists ADD COLUMN artist_age TEXT');
      }
    ]);
  });
}
