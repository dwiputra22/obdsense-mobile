import '../../models/telemetry_data.dart';

class EcoDrivingScorer {
  static const _highRpmThreshold = 3000.0; // ambang umum mesin bensin NA kecil
  static const _harshThrottleThreshold = 75.0; // persen
  static const _idleRpmThreshold = 600.0;
  static const _harshSpeedDeltaKmh = 8.0; // per sample (~2 detik)

  static int score(List<TelemetryData> samples) {
    if (samples.length < 3) return 100; // data terlalu sedikit untuk dinilai

    final penalty = _harshThrottlePenalty(samples) +
        _highRpmPenalty(samples) +
        _idlingPenalty(samples) +
        _speedSmoothnessPenalty(samples);

    return (100 - penalty).clamp(0, 100).round();
  }

  /// Maks potongan 30 poin - proporsi waktu throttle di atas ambang kasar.
  static double _harshThrottlePenalty(List<TelemetryData> samples) {
    final harshCount = samples.where((s) => s.throttlePosition > _harshThrottleThreshold).length;
    return (harshCount / samples.length) * 30;
  }

  /// Maks potongan 25 poin - proporsi waktu RPM di atas ambang efisien.
  static double _highRpmPenalty(List<TelemetryData> samples) {
    final highCount = samples.where((s) => s.rpm > _highRpmThreshold).length;
    return (highCount / samples.length) * 25;
  }

  /// Maks potongan 20 poin - proporsi waktu idle berlebihan (diam tapi
  /// mesin menyala di atas RPM idle normal - mis. macet lama tanpa
  /// mematikan mesin).
  static double _idlingPenalty(List<TelemetryData> samples) {
    final idleCount = samples.where((s) => s.speed < 2 && s.rpm > _idleRpmThreshold).length;
    return (idleCount / samples.length) * 20;
  }

  /// Maks potongan 25 poin - rata-rata perubahan kecepatan antar sample,
  /// proxy untuk akselerasi/pengereman mendadak (bukan pengukuran G-force
  /// langsung karena app ini tidak baca data accelerometer).
  static double _speedSmoothnessPenalty(List<TelemetryData> samples) {
    if (samples.length < 2) return 0;
    double totalDelta = 0;
    for (int i = 1; i < samples.length; i++) {
      totalDelta += (samples[i].speed - samples[i - 1].speed).abs();
    }
    final avgDelta = totalDelta / (samples.length - 1);
    final ratio = (avgDelta / _harshSpeedDeltaKmh).clamp(0.0, 1.0);
    return ratio * 25;
  }

  /// Label kualitatif untuk ditampilkan di UI.
  static String label(int score) {
    if (score >= 85) return 'Sangat Efisien';
    if (score >= 70) return 'Efisien';
    if (score >= 50) return 'Cukup';
    return 'Agresif';
  }
}
