import 'package:test/test.dart';
import 'package:xqflite/xqflite.dart';

final class Database extends XqfliteDatabase {
  Database._();

  static final Database _instance = Database._();
  static Database get instance => _instance;

  DbTableWithConverter<Artist> get artists => tables['artists']!.withConverter((
        toDb: (artist) => artist.toMap(),
        fromDb: Artist.fromMap,
      ));
  DbTableWithConverter<Album> get albums => tables['albums']!.withConverter((
        toDb: (album) => album.toMap(),
        fromDb: Album.fromMap,
      ));
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

class Album {
  final int? albumId;
  final String albumName;
  final int artistId;

  const Album({
    required this.albumName,
    required this.artistId,
    this.albumId,
  });

  Map<String, dynamic> toMap() {
    return {
      'album_name': albumName,
      'album_id': albumId,
      'artist_id': artistId,
    };
  }

  static Album fromMap(Map<String, dynamic> map) {
    return Album(
      albumName: map['album_name'],
      albumId: map['album_id'],
      artistId: map['artist_id'],
    );
  }

  @override
  String toString() {
    return 'Album(albumName: $albumName, albumId: $albumId, artistId: $artistId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Album && other.albumName == albumName && other.albumId == albumId && other.artistId == artistId;
  }

  @override
  int get hashCode => albumName.hashCode ^ albumId.hashCode ^ artistId.hashCode;
}

void testDb(String label, Future<void> Function(Database db) runner) {
  test(label, () async {
    final artistsTable = Table.builder('artists')
        .text('artist_name')
        .primaryKey('artist_id') //
        .build();

    final albumsTable = Table.builder('albums').text('album_name').primaryKey('album_id').reference('artist_id', artistsTable).build();

    final schema = Schema([artistsTable, albumsTable]);

    await Database.instance.open(schema, dbPath: ':memory:');

    await runner(Database.instance);

    await Database.instance.close();
  });
}
