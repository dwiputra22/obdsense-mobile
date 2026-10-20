import '../../models/telemetry_data.dart';

class FuelEfficiencyCalculator {
  /// Rasio udara:bensin stoikiometri untuk bensin (massa) - nilai baku
  /// yang dipakai luas di industri, bukan spesifik satu mesin.
  static const stoichiometricAfr = 14.7;

  /// Kepadatan bensin, gram per liter. Sedikit bervariasi tergantung
  /// jenis BBM (Pertalite/Pertamax/dst) dan suhu, ~730-760 g/L - 750
  /// dipakai sebagai titik tengah yang wajar.
  static const gasolineDensityGPerL = 750.0;

  /// Selisih waktu antar sampel yang lebih besar dari ini dianggap "tidak ada
  /// data" (mis. koneksi sempat putus) dan tidak ikut diintegrasikan, supaya
  /// BBM/jarak tidak ditambah untuk periode yang tidak terukur.
  static const maxSampleGap = Duration(seconds: 5);

  /// Laju BBM (L/jam) dari Mass Air Flow - dipakai sebagai FALLBACK kalau
  /// ECU tidak merespons PID 015E (Engine Fuel Rate) secara langsung,
  /// yang cukup umum terjadi di banyak mesin bensin non-diesel.
  static double? fuelRateFromMaf(double? mafGramsPerSec) {
    if (mafGramsPerSec == null || mafGramsPerSec <= 0) return null;
    final fuelMassPerSec = mafGramsPerSec / stoichiometricAfr;
    final fuelVolumePerSecL = fuelMassPerSec / gasolineDensityGPerL;
    return fuelVolumePerSecL * 3600;
  }

  /// Konsumsi instan dalam km/L dari laju BBM (L/jam) dan kecepatan (km/jam).
  /// Null kalau kecepatan terlalu rendah (mendekati diam) - pada kecepatan
  /// sangat rendah rasio ini tidak bermakna.
  static double? instantKmPerLiter(double? fuelRateLph, double speedKmh) {
    if (fuelRateLph == null || fuelRateLph <= 0 || speedKmh < 5) return null;
    return speedKmh / fuelRateLph;
  }

  /// Total BBM terpakai (liter) = integral laju BBM terhadap WAKTU NYATA
  /// (timestamp tiap sampel, aturan trapesium). Sebelumnya memakai interval
  /// tetap 2 detik padahal sampel masuk tiap ~0,4 detik, sehingga BBM
  /// terhitung berlipat-lipat dari yang sebenarnya.
  static double integrateFuelUsed(List<TelemetryData> samples) {
    if (samples.length < 2) return 0;
    var liters = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final dt = samples[i].timestamp.difference(samples[i - 1].timestamp);
      if (dt <= Duration.zero || dt > maxSampleGap) continue;
      final avgRateLph = (samples[i].fuelRateLph + samples[i - 1].fuelRateLph) / 2;
      liters += avgRateLph * (dt.inMilliseconds / 3600000);
    }
    return liters;
  }

  /// Jarak tempuh (km) dari integrasi kecepatan OBD terhadap waktu nyata.
  /// Dipakai sebagai pembanding / cadangan jarak GPS.
  static double integrateDistanceKm(List<TelemetryData> samples) {
    if (samples.length < 2) return 0;
    var km = 0.0;
    for (var i = 1; i < samples.length; i++) {
      final dt = samples[i].timestamp.difference(samples[i - 1].timestamp);
      if (dt <= Duration.zero || dt > maxSampleGap) continue;
      final avgSpeedKmh = (samples[i].speed + samples[i - 1].speed) / 2;
      km += avgSpeedKmh * (dt.inMilliseconds / 3600000);
    }
    return km;
  }

  /// km/L untuk satu perjalanan. Null kalau jarak atau BBM terlalu kecil untuk
  /// menghasilkan angka yang bermakna.
  static double? kmPerLiter(double distanceKm, double fuelUsedLiters) {
    if (distanceKm < 0.2 || fuelUsedLiters < 0.005) return null;
    return distanceKm / fuelUsedLiters;
  }
}
