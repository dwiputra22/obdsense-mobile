import '../../models/dtc_code.dart';

class DtcParser {
  static List<DtcCode> parse(String raw) {
    final cleaned = raw
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('>', '')
        .replaceAll(' ', '')
        .toUpperCase();

    if (!cleaned.startsWith('43')) {
      return [];
    }

    final payload = cleaned.substring(2);
    final codes = <DtcCode>[];

    for (int i = 0; i + 3 < payload.length; i += 4) {
      final code = decodeSingleDtc(payload.substring(i, i + 4));
      if (code != null) {
        codes.add(
          DtcCode(
            code: code,
            description: _description(code),
            severity: _severity(code),
          ),
        );
      }
    }

    return codes;
  }

  static String? decodeSingleDtc(String fourHexChars) {
    if (fourHexChars == '0000') return null;
    final first = int.parse(fourHexChars[0], radix: 16);
    final type = ['P', 'C', 'B', 'U'][first >> 2];
    final digit1 = (first & 0x3).toString();
    return '$type$digit1${fourHexChars.substring(1)}';
  }

  static String _description(String code) {
    switch (code) {
      case 'P0115':
        return 'Masalah pada sensor suhu coolant mesin';
      case 'P0128':
        return 'Suhu coolant di bawah temperatur kerja normal';
      case 'P0300':
        return 'Random misfire terdeteksi';
      case 'P0420':
        return 'Efisiensi catalytic converter rendah';
      default:
        return 'Kode gangguan terdeteksi, perlu pemeriksaan lebih lanjut';
    }
  }

  static String _severity(String code) {
    if (code.startsWith('P03')) return 'high';
    if (code.startsWith('P01')) return 'medium';
    return 'medium';
  }
}