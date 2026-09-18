import 'obd_parser.dart';

class PidSupportChecker {
  static Set<String> parseBitmask(String raw, String header, int basePid) {
    final s = ObdParser.sanitize(raw);
    final idx = s.indexOf(header);
    if (idx == -1 || s.length < idx + header.length + 8) return {};

    final dataHex = s.substring(idx + header.length, idx + header.length + 8);
    final bits = int.parse(dataHex, radix: 16);

    final supported = <String>{};
    for (int i = 0; i < 32; i++) {
      final bitSet = (bits >> (31 - i)) & 1 == 1;
      if (bitSet) {
        final pidNum = basePid + i + 1;
        supported.add(pidNum.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return supported;
  }

  static bool hasNextGroup(Set<String> supportedInGroup, int groupEndPid) {
    return supportedInGroup.contains(groupEndPid.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
}
