import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/recording_session.dart';
import '../../models/telemetry_data.dart';

class DataRecordingService {
  final List<TelemetryData> _samples = [];
  DateTime? _startedAt;

  bool get isRecording => _startedAt != null;
  int get sampleCount => _samples.length;

  void start() {
    _samples.clear();
    _startedAt = DateTime.now();
  }

  void addSample(TelemetryData data) {
    if (_startedAt == null) return;
    _samples.add(data);
  }

  RecordingSession? stop() {
    if (_startedAt == null) return null;
    final session = RecordingSession(
      startedAt: _startedAt!,
      endedAt: DateTime.now(),
      samples: List<TelemetryData>.from(_samples),
    );
    _startedAt = null;
    _samples.clear();
    return session;
  }

  String toCsv(RecordingSession session) {
    final buffer = StringBuffer();
    buffer.writeln(
      'timestamp,rpm,speed_kmh,coolant_c,voltage,engine_load_pct,'
      'throttle_pct,intake_temp_c,fuel_rate_lph,fuel_level_pct',
    );
    for (final s in session.samples) {
      buffer.writeln([
        s.timestamp.toIso8601String(),
        s.rpm,
        s.speed,
        s.coolantTempC,
        s.batteryVoltage,
        s.engineLoad,
        s.throttlePosition,
        s.intakeTempC,
        s.fuelRateLph,
        s.fuelLevelPercent,
      ].join(','));
    }
    return buffer.toString();
  }

  Future<String> exportToFile(RecordingSession session) async {
    final dir = await getTemporaryDirectory();
    final filename = 'rushsense_recording_${session.startedAt.millisecondsSinceEpoch}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(toCsv(session));
    return file.path;
  }
}
