import 'package:cuid2/cuid2.dart';
import 'package:uuid/uuid.dart';
import 'package:xqflite/src/table.dart';

import 'data_types.dart';

sealed class Column {
  final String name;

  const Column(this.name);

  static TextColumn text(String name, {bool nullable = false, String? defaultValue, bool unique = false}) =>
      TextColumn(name, nullable: nullable, defaultValue: defaultValue, unique: unique);
  static JsonColumn json(String name, {bool nullable = false}) => JsonColumn(name, nullable: nullable);
  static GenericColumn integer(String name, {bool nullable = false, bool unique = false}) =>
      GenericColumn(name, DataType.integer, nullable: nullable, unique: unique);
  static GenericColumn date(String name, {bool nullable = false, bool unique = false}) =>
      GenericColumn(name, DataType.date, nullable: nullable, unique: unique);
  static GenericColumn dateTime(String name, {bool nullable = false, bool unique = false}) =>
      GenericColumn(name, DataType.dateTime, nullable: nullable, unique: unique);
  static PrimaryKeyColumn primaryKey(String name) => PrimaryKeyColumn(name);
  static PrimaryKeyCuidColumn primaryKeyCuid(String name) => PrimaryKeyCuidColumn(name);
  static PrimaryKeyUuidColumn primaryKeyUuid(String name) => PrimaryKeyUuidColumn(name);
  static ReferenceColumn reference(String name, Table table, {bool nullable = false, CascadeOperation? onUpdate, CascadeOperation? onDelete}) =>
      ReferenceColumn(name, references: table, nullable: nullable, onDelete: onDelete, onUpdate: onUpdate);

  String toSql();

  Object? defaultValueGetter() => null;
}

abstract interface class IntoPrimaryKey {
  SingleColumnKey toKey();
}

/// This creates a column which is primary key type integer
final class PrimaryKeyColumn extends Column implements IntoPrimaryKey {
  const PrimaryKeyColumn(super.name);

  @override
  String toSql() => '$name INTEGER PRIMARY KEY';

  SingleColumnKey toKey() => SingleColumnKey(this);
}

final class PrimaryKeyCuidColumn extends Column implements IntoPrimaryKey {
  const PrimaryKeyCuidColumn(super.name);

  @override
  String toSql() => '$name TEXT PRIMARY KEY NOT NULL';

  SingleColumnKey toKey() => SingleColumnKey(this);

  @override
  String? defaultValueGetter() {
    return cuid();
  }
}

final class PrimaryKeyUuidColumn extends Column implements IntoPrimaryKey {
  const PrimaryKeyUuidColumn(super.name);

  @override
  String toSql() => '$name TEXT PRIMARY KEY NOT NULL';

  SingleColumnKey toKey() => SingleColumnKey(this);

  @override
  String? defaultValueGetter() {
    return Uuid().v8();
  }
}

final class GenericColumn extends Column {
  final DataType dataType;
  final bool nullable;
  final bool unique;

  const GenericColumn(super.name, this.dataType, {this.nullable = false, this.unique = false});

  @override
  String toSql() => '$name ${dataType.name.toUpperCase()}${nullable ? '' : ' NOT NULL'}${unique ? ' UNIQUE' : ''}';
}

final class TextColumn extends Column {
  final bool nullable;
  final bool unique;
  final String? defaultValue;

  const TextColumn(super.name, {this.nullable = false, this.defaultValue, this.unique = false});

  @override
  String toSql() => '$name TEXT${defaultValue == null ? '' : ' DEFAULT "$defaultValue"'}${nullable ? '' : ' NOT NULL'}${unique ? ' UNIQUE' : ''}';
}

/// https://www.sqlite.org/foreignkeys.html
enum CascadeOperation {
  noAction("NO ACTION"),
  restrict("RESTRICT"),
  setNull("SET NULL"),
  setDefault("SET DEFAULT"),
  cascade("CASCADE");

  final String sql;
  const CascadeOperation(this.sql);
}

final class ReferenceColumn extends Column {
  final Table references;
  final bool nullable;
  final CascadeOperation? onDelete;
  final CascadeOperation? onUpdate;
  final DataAffinity type;

  const ReferenceColumn(super.name, {required this.references, this.nullable = false, this.onUpdate, this.onDelete, this.type = DataAffinity.integer});

  @override
  String toSql() {
    final buffer = StringBuffer('$name ${type.name} REFERENCES ${references.name} (${references.primaryKey.toSqlList()})');

    if (onDelete != null) {
      buffer.write(" ON DELETE ");
      buffer.write(onDelete!.sql);
    }

    if (onUpdate != null) {
      buffer.write(" ON UPDATE ");
      buffer.write(onUpdate!.sql);
    }

    return buffer.toString();
  }
}

final class JsonColumn extends Column {
  final bool nullable;

  const JsonColumn(super.name, {this.nullable = false});

  @override
  String toSql() => '$name JSON${nullable ? '' : ' NOT NULL'}';
}

// class Column {

// class Column {
//   const Column({
//     this.isPrimaryKey = false,
//     required this.name,
//     required this.dataType,
//     this.nullable = false,
//     this.references,
//   });

//   String toSql() {
//     final buffer = StringBuffer();

//     buffer.write(name);

//     buffer.write(' ${dataType.name.toUpperCase()}');
//     if (!nullable && !isPrimaryKey) buffer.write(' NOT NULL');
//     if (isPrimaryKey) buffer.write(' PRIMARY KEY');
//     if (references != null) buffer.write(' REFERENCES ${references!.name} (${references!.primaryKey.toSqlList()})');

//     return buffer.toString();
//   }

//   SingleColumnKey toKey() => SingleColumnKey(this);

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Column && //
//           other.dataType == dataType &&
//           other.name == name &&
//           other.references == references &&
//           other.nullable == nullable;

//   @override
//   int get hashCode => Object.hash(dataType, name, nullable, references);

//   @override
//   String toString() => 'Column[dataType=$dataType, name=$name, nullable=$nullable]';
// }
