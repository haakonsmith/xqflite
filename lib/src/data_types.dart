sealed class DataAffinityType {}

class TextAffinityType extends DataAffinityType {}
class NumericAffinityType extends DataAffinityType  {}
class IntegerAffinityType extends DataAffinityType {}
class RealAffinityType extends DataAffinityType  {}

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
