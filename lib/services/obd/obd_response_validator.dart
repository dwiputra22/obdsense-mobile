class ObdResponseValidator {
  static bool isValid(String raw) {
    final cleaned = raw
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();

    if (cleaned.isEmpty) return false;
    if (cleaned.contains('NODATA')) return false;
    if (cleaned.contains('?')) return false;
    return true;
  }

  static bool containsPidResponse(String raw, String expectedHeader) {
    final cleaned = raw
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();

    return cleaned.contains(expectedHeader);
  }
}