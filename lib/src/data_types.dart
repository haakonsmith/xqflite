sealed class DataAffinityType<Internal> {
  String get name;
}

class TextAffinityType extends DataAffinityType<String> {
  @override
  String get name => "TEXT";
}

class IntegerAffinityType extends DataAffinityType<int> {
  @override
  String get name => "INTEGER";
}

class RealAffinityType extends DataAffinityType<double> {
  @override
  String get name => "REAL";
}

enum DataAffinity { text, numeric, integer, real, blob, json }

enum DataType {
  integer(DataAffinity.integer),
  text(DataAffinity.text),
  json(DataAffinity.json),
  date(DataAffinity.numeric),
  bytes(DataAffinity.numeric),
  dateTime(DataAffinity.numeric),
  boolean(DataAffinity.numeric),
  real(DataAffinity.real);

  final DataAffinity affinity;

  const DataType(this.affinity);
}
