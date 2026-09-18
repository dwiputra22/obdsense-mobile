class FuelEfficiencyCalculator {
  /// Rasio udara:bensin stoikiometri untuk bensin (massa) - nilai baku
  /// yang dipakai luas di industri, bukan spesifik satu mesin.
  static const stoichiometricAfr = 14.7;

  /// Kepadatan bensin, gram per liter. Sedikit bervariasi tergantung
  /// jenis BBM (Pertalite/Pertamax/dst) dan suhu, ~730-760 g/L - 750
  /// dipakai sebagai titik tengah yang wajar.
  static const gasolineDensityGPerL = 750.0;

  /// Laju BBM (L/jam) dari Mass Air Flow - dipakai sebagai FALLBACK kalau
  /// ECU tidak merespons PID 015E (Engine Fuel Rate) secara langsung,
  /// yang cukup umum terjadi di banyak mesin bensin non-diesel.
  static double? fuelRateFromMaf(double? mafGramsPerSec) {
    if (mafGramsPerSec == null || mafGramsPerSec <= 0) return null;
    final fuelMassPerSec = mafGramsPerSec / stoichiometricAfr;
    final fuelVolumePerSecL = fuelMassPerSec / gasolineDensityGPerL;
    return fuelVolumePerSecL * 3600;
  }

  /// Konsumsi instan dalam L/100km dari laju BBM (L/jam) dan kecepatan
  /// (km/jam). Null kalau kecepatan terlalu rendah (mendekati diam) -
  /// pada kecepatan sangat rendah rasio ini meledak ke angka yang tidak
  /// bermakna, bukan cerminan efisiensi berkendara sesungguhnya.
  static double? instantLPer100Km(double? fuelRateLph, double speedKmh) {
    if (fuelRateLph == null || fuelRateLph <= 0 || speedKmh < 5) return null;
    return (fuelRateLph / speedKmh) * 100;
  }

  /// Total BBM terpakai (liter) dari serangkaian laju BBM (L/jam) yang
  /// dicatat tiap interval waktu tertentu - integrasi sederhana
  /// (persegi panjang, bukan trapesium) karena interval sampling (~2
  /// detik) sudah cukup rapat untuk mesin kendaraan biasa.
  static double integrateFuelUsed(List<double> fuelRatesLph, Duration sampleInterval) {
    if (fuelRatesLph.isEmpty) return 0;
    final hoursPerSample = sampleInterval.inMilliseconds / 3600000;
    return fuelRatesLph.fold<double>(0, (sum, rate) => sum + (rate * hoursPerSample));
  }
}
