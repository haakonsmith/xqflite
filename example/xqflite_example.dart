import 'package:flutter/material.dart';

import 'lib/todo_page.dart';

void main() {
  runApp(const XqfliteExample());
}

class XqfliteExample extends StatelessWidget {
  const XqfliteExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.purple,
        useMaterial3: true,
        brightness: Brightness.dark,
        inputDecorationTheme: const InputDecorationTheme(isDense: true),
        toggleButtonsTheme: const ToggleButtonsThemeData(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          constraints: BoxConstraints(
            minHeight: 40,
            minWidth: 80,
          ),
        ),
        dataTableTheme: const DataTableThemeData(),
        navigationRailTheme: const NavigationRailThemeData(),
      ),
      home: TodoPage(),
    );
  }
}
