import 'package:test/test.dart';

import 'shared.dart';

void main() {
  group('xqflite hooks tests', () {
    testDb("any table change", (db) async {
      int counter = 0;
      db.tableChangeStream.listen((element) {
        counter++;
      });

      await db.artists.insert(Artist(artistName: "test"));

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table update", (db) async {
      int counter = 0;
      db.tableUpdateStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");
      final id = await db.artists.insert(artist);

      await db.artists.updateId(artist.copyWith(artistId: () => id), id);

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table delete", (db) async {
      int counter = 0;
      db.tableDeleteStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");
      final id = await db.artists.insert(artist);

      await db.artists.deleteId(id);

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table insert", (db) async {
      int counter = 0;

      db.tableInsertStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");
      await db.artists.insert(artist);

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });
  });

  group('xqflite batch hooks tests', () {
    testDb("any table change", (db) async {
      int counter = 0;
      db.tableChangeStream.listen((element) {
        counter++;
      });

      await db.artists.batch((batch) {
        batch.insert(Artist(artistName: "test"));
      });

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table update", (db) async {
      int counter = 0;
      db.tableUpdateStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");

      final id = await db.artists.insert(artist);

      await db.batch((batch) {
        db.artists.updateId(artist.copyWith(artistId: () => id), id);
      });

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table delete", (db) async {
      int counter = 0;
      db.tableDeleteStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");
      final id = await db.artists.insert(artist);

      await db.batch((batch) {
        db.artists.deleteId(id);
      });

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });

    testDb("table insert", (db) async {
      int counter = 0;

      db.tableInsertStream.listen((element) {
        counter++;
      });

      final artist = Artist(artistName: "test");

      await db.batch((batch) {
        db.artists.insert(artist);
      });

      /// Streams get updated in a micro task after called, so if we await one more micro task it will be updated
      await Future.microtask(() {});

      expect(counter, 1);
    });
  });
}
