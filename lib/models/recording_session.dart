import 'telemetry_data.dart';

class RecordingSession {
  final DateTime startedAt;
  final DateTime endedAt;
  final List<TelemetryData> samples;

  const RecordingSession({
    required this.startedAt,
    required this.endedAt,
    required this.samples,
  });
}
