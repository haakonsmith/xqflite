class XqfliteException implements Exception {}

class XqfliteGenericException implements XqfliteException {
  final Object exception;

  const XqfliteGenericException(this.exception);

  @override
  String toString() {

    return "$exception";
  }
}
