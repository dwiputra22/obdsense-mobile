import '../../models/anomaly.dart';

/// Skor 0-100 gabungan dari beberapa sinyal yang sudah dibaca app ini -
/// BUKAN skor tersertifikasi/divalidasi industri, tapi ringkasan yang
/// masuk akal dari data yang ada: kode error aktif, kelengkapan monitor
/// emisi, dan anomali dibanding baseline mobil ini sendiri.
class VehicleHealthScoreCalculator {
  static int calculate({
    required int dtcCount,
    required bool milOn,
    double? readinessCompletionRatio,
    List<Anomaly> recentAnomalies = const [],
  }) {
    double score = 100;

    if (milOn) score -= 25;
    score -= dtcCount * 10;

    if (readinessCompletionRatio != null) {
      score -= (1 - readinessCompletionRatio) * 10;
    }

    for (final a in recentAnomalies) {
      score -= a.severity == 'warning' ? 8 : 4;
    }

    return score.clamp(0, 100).round();
  }

  static String label(int score) {
    if (score >= 90) return 'Sangat Baik';
    if (score >= 70) return 'Baik';
    if (score >= 50) return 'Perlu Perhatian';
    return 'Butuh Pengecekan Segera';
  }
}
