import 'package:xqflite/xqflite.dart';

String buildUpdateStatement(String tableName, Map<String, dynamic> args, Query? query) {
  final buffer = StringBuffer();

  buffer.writeln("UPDATE $tableName SET ");

  buffer.writeln(args.keys.map((e) => "$e = ?").join(", "));
  // for (final key in args.keys) {
  //   buffer.writeln("$key = ?,");
  // }

  if (query != null) {
    buffer.write("WHERE");
    buffer.write(query.whereString());
  }

  return buffer.toString();
}

// String replaceQueryPlaceholders(String query, List<Object?> values) {
//   int i = 0;
//   query.replaceAllMapped("?", (Match m) => m.[](group))
// }

String buildQueryStatement(Table table, Query query) {
  final buffer = StringBuffer();

  buffer.write("SELECT ");

  if (query.distinct) {
    buffer.write(" DISTINCT ");
  }

  buffer.write(query.columns?.join(", ") ?? '*');
  buffer.write(" FROM ");

  buffer.writeln(table.tableIdQuery());

  final queryStr = query.whereStringOrNull();

  if (queryStr != null) {
    buffer.writeln("WHERE");
    buffer.writeln(queryStr);
  }

  final orderByStr = query.orderByString();

  if (orderByStr != null) {
    buffer.write("ORDER BY ");
    buffer.writeln(orderByStr);
  }

  if (query.limit != null) {
    buffer.writeln("LIMIT ${query.limit}");
  }

  return buffer.toString();
}
