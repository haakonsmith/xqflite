import 'package:flutter/material.dart';
import 'package:xqflite/src/query.dart';

import 'db.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await Database.instance.init();

      setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: Database.instance.when((db) => db.todos.watch(Query.all())),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final todo = snapshot.data![index];

              return ListTile(
                title: Text(todo.name + todo.id.toString()),
                subtitle: Text(todo.description),
                trailing: IconButton(
                  onPressed: () {
                    Database.instance.todos.deleteId(todo.id!);
                  },
                  icon: Icon(Icons.delete),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);

                await Database.instance.todos.insert(Todo(name: 'My task', description: "test"));

                setState(() => _loading = false);
              },
        label: _loading ? const Center(child: CircularProgressIndicator()) : Text('Add'),
      ),
    );
  }
}
