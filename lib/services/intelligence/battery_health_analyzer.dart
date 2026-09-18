import '../../models/running_stat.dart';
import 'driving_state_classifier.dart';
import 'vehicle_baseline_service.dart';

class BatteryHealthStatus {
  final RunningStat? idleVoltage;
  final RunningStat? cityVoltage;
  final RunningStat? highwayVoltage;
  final String assessment;
  final String severity; // 'good' | 'watch' | 'warning' | 'unknown'

  const BatteryHealthStatus({
    required this.idleVoltage,
    required this.cityVoltage,
    required this.highwayVoltage,
    required this.assessment,
    required this.severity,
  });
}

/// OBD-II cuma bisa dibaca saat ECU aktif (kontak
/// minimal ON), jadi app ini TIDAK BISA membedakan "voltase aki saat
/// mesin benar-benar mati" (idle rest voltage, indikator klasik
/// kesehatan aki) dari "voltase saat idle dengan mesin menyala"
/// (dipengaruhi alternator, bukan cuma aki). Analisa di bawah pakai
/// voltase SAAT MESIN MENYALA di berbagai kondisi - itu tetap berguna
/// untuk deteksi masalah alternator/aki, tapi beda dari cara bengkel
/// mengukur aki dengan multimeter saat kontak benar-benar mati.
class BatteryHealthAnalyzer {
  static const _healthyMin = 13.2;
  static const _healthyMax = 14.8;
  static const _weakThreshold = 12.8;

  static BatteryHealthStatus analyze(String vin, VehicleBaselineService baselineService) {
    final idle = baselineService.getBaseline(vin, 'batteryVoltage', DrivingState.idle);
    final city = baselineService.getBaseline(vin, 'batteryVoltage', DrivingState.city);
    final highway = baselineService.getBaseline(vin, 'batteryVoltage', DrivingState.highway);

    final reference = idle ?? city ?? highway;
    if (reference == null || !reference.isReliable) {
      return const BatteryHealthStatus(
        idleVoltage: null,
        cityVoltage: null,
        highwayVoltage: null,
        assessment: 'Belum cukup data untuk menilai kesehatan aki/alternator - '
            'butuh lebih banyak riwayat berkendara.',
        severity: 'unknown',
      );
    }

    final mean = reference.mean;
    String assessment;
    String severity;

    if (mean < _weakThreshold) {
      assessment = 'Voltase rata-rata rendah (${mean.toStringAsFixed(1)}V) - kemungkinan '
          'aki melemah atau alternator tidak mengisi optimal. Cek di bengkel.';
      severity = 'warning';
    } else if (mean < _healthyMin) {
      assessment = 'Voltase rata-rata sedikit di bawah normal (${mean.toStringAsFixed(1)}V) - '
          'masih dalam batas wajar, tapi perlu dipantau.';
      severity = 'watch';
    } else if (mean > _healthyMax) {
      assessment = 'Voltase rata-rata tinggi (${mean.toStringAsFixed(1)}V) - kemungkinan '
          'regulator alternator bermasalah (overcharging). Cek di bengkel.';
      severity = 'warning';
    } else {
      assessment = 'Voltase rata-rata normal (${mean.toStringAsFixed(1)}V) - aki dan '
          'alternator kemungkinan sehat.';
      severity = 'good';
    }

    return BatteryHealthStatus(
      idleVoltage: idle,
      cityVoltage: city,
      highwayVoltage: highway,
      assessment: assessment,
      severity: severity,
    );
  }
}
