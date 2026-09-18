import '../../models/readiness_status.dart';
import 'obd_parser.dart';

class ReadinessParser {
  static ReadinessStatus? parse(String raw) {
    final s = ObdParser.sanitize(raw);
    final idx = s.indexOf('4101');
    if (idx == -1 || s.length < idx + 12) return null;

    final a = int.parse(s.substring(idx + 4, idx + 6), radix: 16);
    final b = int.parse(s.substring(idx + 6, idx + 8), radix: 16);
    final c = int.parse(s.substring(idx + 8, idx + 10), radix: 16);
    final d = int.parse(s.substring(idx + 10, idx + 12), radix: 16);

    final milOn = (a & 0x80) != 0;
    final dtcCount = a & 0x7F;
    final isCompression = (b & 0x08) != 0;

    final monitors = <ReadinessMonitor>[
      ReadinessMonitor(
        name: 'Misfire (Salah Pembakaran)',
        supported: (b & 0x01) != 0,
        ready: (b & 0x10) == 0,
      ),
      ReadinessMonitor(
        name: 'Sistem Bahan Bakar',
        supported: (b & 0x02) != 0,
        ready: (b & 0x20) == 0,
      ),
      ReadinessMonitor(
        name: 'Komponen Emisi Lainnya',
        supported: (b & 0x04) != 0,
        ready: (b & 0x40) == 0,
      ),
    ];

    if (!isCompression) {
      final sparkMonitors = [
        ('Catalytic Converter', 0x01),
        ('Catalytic Converter (Dipanaskan)', 0x02),
        ('Sistem Evaporative', 0x04),
        ('Sistem Udara Sekunder', 0x08),
        ('Sensor A/C Refrigerant', 0x10),
        ('Sensor Oksigen', 0x20),
        ('Pemanas Sensor Oksigen', 0x40),
        ('Sistem EGR', 0x80),
      ];
      for (final (name, bitmask) in sparkMonitors) {
        final supported = (c & bitmask) != 0;
        if (!supported) continue; // jangan tampilkan monitor yang memang tidak ada di mesin ini
        monitors.add(ReadinessMonitor(
          name: name,
          supported: true,
          ready: (d & bitmask) == 0,
        ));
      }
    }

    return ReadinessStatus(
      milOn: milOn,
      dtcCount: dtcCount,
      isCompressionIgnition: isCompression,
      monitors: monitors,
    );
  }
}
