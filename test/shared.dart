import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:xqflite/xqflite.dart';

final class Database extends XqfliteDatabase {
  Database._();

  static final Database _instance = Database._();
  static Database get instance => _instance;

  // DbTableWithConverter<int, Artist> get artists => (tables['artists']! as DbTable<int>).withConverter<Artist>((
  //       toDb: (artist) => artist.toMap(),
  //       fromDb: Artist.fromMap,
  //     ));
  DbTableWithConverter<int, Artist> get artists =>
      getTableWithConverter('artists', (
        toDb: (artist) => artist.toMap(),
        fromDb: Artist.fromMap,
      ));
  DbTableWithConverter<int, Album> get albums =>
      tables['albums']!.withConverter<Album>((
        toDb: (album) => album.toMap(),
        fromDb: Album.fromMap,
      )) as DbTableWithConverter<int, Album>;
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

  Artist copyWith({
    String? artistName,
    ValueGetter<int?>? artistId,
  }) {
    return Artist(
      artistName: artistName ?? this.artistName,
      artistId: artistId != null ? artistId() : this.artistId,
    );
  }
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

    return other is Album &&
        other.albumName == albumName &&
        other.albumId == albumId &&
        other.artistId == artistId;
  }

  @override
  int get hashCode => albumName.hashCode ^ albumId.hashCode ^ artistId.hashCode;
}

/// Provides you with an in memory database that has the following characteristics
///
/// ```md
/// Table: artists
///   - artist_name: text
///   - artist_id: int PRIMARY KEY
///
/// Table: albums
///   - album_name: text
///   - album_id: int PRIMARY KEY
///   - artist_id: int References artists
/// ```
void testDb(
  String label,
  Future<void> Function(Database db) runner, {
  List<Migration> migrations = const [],
  int? initialVersion,
}) {
  test(label, () async {
    final artistsTable = Table.builder('artists')
        .text('artist_name')
        .primaryKey('artist_id') //
        .build();

    final albumsTable = Table.builder('albums') //
        .text('album_name')
        .primaryKey('album_id')
        .reference('artist_id', artistsTable)
        .build();

    final schema = Schema([artistsTable, albumsTable], migrations: migrations);

    await Database.instance.open(
      schema,
      dbPath: ':memory:',
      onBeforeMigration: (db) async {
        if (initialVersion != null) {
          await db.execute('PRAGMA user_version = ${initialVersion + 1}');
        }
      },
    );

    await runner(Database.instance).whenComplete(Database.instance.close);
  });
}
