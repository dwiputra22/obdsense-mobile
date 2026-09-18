class ObdParser {
  static String sanitize(String raw) {
    return raw
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('>', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();
  }

  static double? parseRpm(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('410C');
    if (idx == -1 || s.length < idx + 8) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    final b = int.parse(s.substring(idx + 6, idx + 8), radix: 16);
    return ((a * 256) + b) / 4;
  }

  static double? parseSpeed(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('410D');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return a.toDouble();
  }

  static double? parseCoolantTempC(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('4105');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return (a - 40).toDouble();
  }

  static double? parseEngineLoad(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('4104');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return (a * 100) / 255;
  }

  static double? parseThrottle(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('4111');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return (a * 100) / 255;
  }

  static double? parseIntakeTempC(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('410F');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return (a - 40).toDouble();
  }

  static double? parseVoltage(String raw) {
    final match = RegExp(r'(\d+\.\d+)V').firstMatch(raw.toUpperCase());
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  static double? parseMaf(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('4110');
    if (idx == -1 || s.length < idx + 8) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    final b = int.parse(s.substring(idx + 6, idx + 8), radix: 16);
    return ((a * 256) + b) / 100;
  }

  static double? parseFuelRate(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('415E');
    if (idx == -1 || s.length < idx + 8) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    final b = int.parse(s.substring(idx + 6, idx + 8), radix: 16);
    return ((a * 256) + b) / 20;
  }

  static double? parseFuelLevel(String raw) {
    final s = sanitize(raw);
    final idx = s.indexOf('412F');
    if (idx == -1 || s.length < idx + 6) return null;
    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    return (a * 100) / 255;
  }
}