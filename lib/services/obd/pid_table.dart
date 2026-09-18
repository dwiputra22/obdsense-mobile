class PidDefinition {
  final String pid;
  final String name;
  final String unit;
  final int expectedBytes;
  final double Function(List<int> bytes) decode;

  const PidDefinition({
    required this.pid,
    required this.name,
    required this.unit,
    required this.expectedBytes,
    required this.decode,
  });
}

class PidTable {
  static final List<PidDefinition> extended = [
    PidDefinition(
      pid: '06',
      name: 'Fuel Trim Jangka Pendek (Bank 1)',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => (b[0] - 128) * 100 / 128,
    ),
    PidDefinition(
      pid: '07',
      name: 'Fuel Trim Jangka Panjang (Bank 1)',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => (b[0] - 128) * 100 / 128,
    ),
    PidDefinition(
      pid: '08',
      name: 'Fuel Trim Jangka Pendek (Bank 2)',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => (b[0] - 128) * 100 / 128,
    ),
    PidDefinition(
      pid: '09',
      name: 'Fuel Trim Jangka Panjang (Bank 2)',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => (b[0] - 128) * 100 / 128,
    ),
    PidDefinition(
      pid: '0A',
      name: 'Tekanan BBM',
      unit: 'kPa',
      expectedBytes: 1,
      decode: (b) => (b[0] * 3).toDouble(),
    ),
    PidDefinition(
      pid: '0B',
      name: 'Tekanan Intake Manifold',
      unit: 'kPa',
      expectedBytes: 1,
      decode: (b) => b[0].toDouble(),
    ),
    PidDefinition(
      pid: '0E',
      name: 'Timing Pengapian',
      unit: '° sebelum TDC',
      expectedBytes: 1,
      decode: (b) => (b[0] - 128) / 2,
    ),
    PidDefinition(
      pid: '1F',
      name: 'Waktu Sejak Mesin Nyala',
      unit: 'detik',
      expectedBytes: 2,
      decode: (b) => ((b[0] * 256) + b[1]).toDouble(),
    ),
    PidDefinition(
      pid: '21',
      name: 'Jarak dengan Lampu Check Engine Menyala',
      unit: 'km',
      expectedBytes: 2,
      decode: (b) => ((b[0] * 256) + b[1]).toDouble(),
    ),
    PidDefinition(
      pid: '2E',
      name: 'Commanded Evaporative Purge',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '33',
      name: 'Tekanan Barometrik',
      unit: 'kPa',
      expectedBytes: 1,
      decode: (b) => b[0].toDouble(),
    ),
    PidDefinition(
      pid: '42',
      name: 'Voltase Modul Kontrol (ECU)',
      unit: 'V',
      expectedBytes: 2,
      decode: (b) => ((b[0] * 256) + b[1]) / 1000,
    ),
    PidDefinition(
      pid: '43',
      name: 'Beban Mesin Absolut',
      unit: '%',
      expectedBytes: 2,
      decode: (b) => ((b[0] * 256) + b[1]) * 100 / 255,
    ),
    PidDefinition(
      pid: '45',
      name: 'Posisi Throttle Relatif',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '46',
      name: 'Suhu Udara Sekitar',
      unit: '°C',
      expectedBytes: 1,
      decode: (b) => (b[0] - 40).toDouble(),
    ),
    PidDefinition(
      pid: '49',
      name: 'Posisi Pedal Gas',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '4C',
      name: 'Commanded Throttle Actuator',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '52',
      name: 'Persentase BBM Etanol',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '5A',
      name: 'Posisi Pedal Gas Relatif',
      unit: '%',
      expectedBytes: 1,
      decode: (b) => b[0] * 100 / 255,
    ),
    PidDefinition(
      pid: '5C',
      name: 'Suhu Oli Mesin',
      unit: '°C',
      expectedBytes: 1,
      decode: (b) => (b[0] - 40).toDouble(),
    ),
  ];
}
