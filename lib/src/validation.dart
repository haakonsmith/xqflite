import 'dart:typed_data';

import 'package:xqflite/src/column.dart';
import 'package:xqflite/src/data_types.dart';

sealed class ValidationError {
  Never throwSelf() {
    throw this;
  }

  const ValidationError();

  String toDisplayString();

  @override
  String toString() => toDisplayString();
}

final class NullableError extends ValidationError {
  final String keyName;
  final Column column;

  const NullableError({required this.keyName, required this.column});

  @override
  String toDisplayString() =>
      "key: $keyName is missing or null in map relating to column: $column (${column.toSql()}).\nHave you made a mistake in the toMap converter? Or forgotten a map key?";
}

final class InvalidTypeError extends ValidationError {
  final Type expected;
  final Type actual;
  final String key;

  InvalidTypeError(this.key, {required this.expected, required this.actual});

  @override
  String toDisplayString() => 'key: $key found type: $actual expected: $expected';
}

extension Validation on List<Column> {
  Map<String, Object?> validateMapExcept(Map<String, Object?> values) {
    validateMap(values)?.throwSelf();

    return values;
  }

  ValidationError? validateMap(Map<String, Object?> values) {
    for (final column in this) {
      var value = values[column.name];

      final dataType = switch (column) {
        PrimaryKeyColumn _ => DataType.integer,
        JsonColumn _ => DataType.json,
        ReferenceColumn _ => DataType.integer,
        TextColumn _ => DataType.text,
        GenericColumn column => column.dataType,
        PrimaryKeyCuidColumn _ => DataType.text,
        PrimaryKeyUuidColumn _ => DataType.text,
      };

      final nullable = switch (column) {
        JsonColumn column => column.nullable,
        GenericColumn column => column.nullable,
        ReferenceColumn column => column.nullable,
        TextColumn column => column.nullable,
        PrimaryKeyColumn _ => true,
        PrimaryKeyCuidColumn _ => true,
        PrimaryKeyUuidColumn _ => true,
      };

      value ??= column.defaultValueGetter();

      if (value == null && !nullable) return NullableError(keyName: column.name, column: column);

      switch (dataType) {
        case DataType.bytes:
          if (value is! Uint8List?) return InvalidTypeError(column.name, expected: Uint8List, actual: value.runtimeType);
          break;
        case DataType.boolean:
          if (value is! bool?) return InvalidTypeError(column.name, expected: bool, actual: value.runtimeType);
          break;
        case DataType.real:
          if (value is! double?) return InvalidTypeError(column.name, expected: double, actual: value.runtimeType);
          break;
        case DataType.integer:
          if (value is! int?) return InvalidTypeError(column.name, expected: int, actual: value.runtimeType);
          break;
        case DataType.text:
          if (value is! String?) return InvalidTypeError(column.name, expected: String, actual: value.runtimeType);
          break;
        case DataType.json:
          if (value is! Map?) return InvalidTypeError(column.name, expected: Map, actual: value.runtimeType);
          break;
        case DataType.dateTime:
          // if (value is! DateTime?) return InvalidTypeError(column.name, expected: DateTime, actual: value.runtimeType);
          if (value is! int?) return InvalidTypeError(column.name, expected: int, actual: value.runtimeType);
          break;
        case DataType.date:
          if (value is! DateTime?) return InvalidTypeError(column.name, expected: DateTime, actual: value.runtimeType);
          break;
      }
    }

    return null;
  }
}
