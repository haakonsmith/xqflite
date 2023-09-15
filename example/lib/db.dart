import 'package:xqflite/src/column.dart';
import 'package:xqflite/xqflite.dart';

class Todo {
  final int? id;
  final String name;
  final String description;

  const Todo({
    this.id,
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'todo_id': id,
      'todo_name': name,
      'todo_description': description,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['todo_id'] as int,
      name: map['todo_name'] as String,
      description: map['todo_description'] as String,
    );
  }

  static Converter<Todo> get converter => (fromDb: Todo.fromMap, toDb: (data) => data.toMap());
}

final class Database extends XqfliteDatabase {
  Database._();

  static final Database _instance = Database._();
  static Database get instance => _instance;
}

extension TodoDatabase on XqfliteDatabase {
  Future<void> migrateV1ToV2(XqfliteDatabase database, int migrationId) async {
    await database.executeBuilder(
      (builder) => builder.alterTable('todo').add(Column.text('todo_description', defaultValue: "No description")),
    );
  }

  Future<void> init() async {
    final todos = Table.builder('todo')
        .primaryKey('todo_id')
        .text('todo_name') //
        .build();

    final schema = Schema([todos]);

    await open(schema, migrations: [
      migrateV1ToV2,
      migrateV1ToV2,
    ]);
  }

  DbTableWithConverter<Todo> get todos => tables['todo']!.withConverter(Todo.converter);
}
