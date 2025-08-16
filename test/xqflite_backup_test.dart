import 'dart:io';

import 'package:libsql_dart/libsql_dart.dart';
import 'package:test/test.dart';
import 'package:xqflite/xqflite.dart';

import 'shared.dart';

void main() {
  test('backup test', () async {
    final directory = Directory.current;

    await Database.instance.connect(LibsqlClient("${directory.path}/test.db"), Schema([]));

    await Database.instance.backup();

    await Database.instance.close();

    expect(File("${directory.path}/test.db.bak").existsSync(), true);

    await File("${directory.path}/test.db.bak").delete();
    await File("${directory.path}/test.db").delete();
  });
}
