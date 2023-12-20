import 'package:xqflite/xqflite.dart';


/// This means that the database does not know how to go from `version` to `version + 1`.
class MigrationMissingError extends Error {
  MigrationMissingError(this.version);

  final int version;

  @override
  String toString() => 'MigrationMissingError: There is no migration for version $version';
}

typedef Migrator = Future<void> Function(XqfliteDatabase db, int version);

/// If the database is [version] then [migrator] will be called.
/// And the database will be updated to the next version.
class Migration {
  const Migration({
    required this.version,
    required this.migrator,
  });

  /// The version of the database that this migration will run on.
  final int version;

  /// This functions takes in the current database and migrates it to the next version.
  /// The database will be updated to the next version.
  /// Mutates the database.
  final Migrator migrator;
}
