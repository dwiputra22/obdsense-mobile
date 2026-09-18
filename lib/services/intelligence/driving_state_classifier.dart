import '../../models/telemetry_data.dart';

/// Baseline "RPM normal" beda artinya kalau mobil idle vs jalan tol -
/// membandingkan semua kondisi jadi satu angka rata-rata tidak berarti
/// apa-apa. Data dikelompokkan per kondisi berkendara dulu, baru
/// masing-masing kondisi punya baseline sendiri.
enum DrivingState { idle, city, highway }

class DrivingStateClassifier {
  static DrivingState classify(TelemetryData data) {
    if (data.speed < 3) return DrivingState.idle;
    if (data.speed < 60) return DrivingState.city;
    return DrivingState.highway;
  }
}
