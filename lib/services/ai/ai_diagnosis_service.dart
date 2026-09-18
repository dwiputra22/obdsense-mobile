import '../../models/ai_insight.dart';
import '../../models/telemetry_data.dart';

class AiDiagnosisService {
  List<AiInsight> analyze(TelemetryData data) {
    final insights = <AiInsight>[];

    if (data.coolantTempC >= 100) {
      insights.add(const AiInsight(
        title: 'Suhu mesin tinggi',
        summary: 'Suhu coolant terdeteksi tinggi. Kurangi beban kendaraan dan periksa sistem pendinginan sesegera mungkin.',
        severity: 'high',
      ));
    } else if (data.coolantTempC >= 92) {
      insights.add(const AiInsight(
        title: 'Suhu mesin meningkat',
        summary: 'Suhu mesin berada di atas pola normal harian. Pantau saat macet atau tanjakan panjang.',
        severity: 'medium',
      ));
    }

    if (data.batteryVoltage > 0 && data.batteryVoltage < 12.3) {
      insights.add(const AiInsight(
        title: 'Voltase aki rendah',
        summary: 'Tegangan aki cenderung rendah. Pemeriksaan aki dan alternator disarankan.',
        severity: 'medium',
      ));
    }

    if (data.engineLoad > 85 && data.speed < 25) {
      insights.add(const AiInsight(
        title: 'Beban mesin tinggi',
        summary: 'Beban mesin tinggi pada kecepatan rendah. Ini dapat meningkatkan panas mesin dan konsumsi bahan bakar.',
        severity: 'medium',
      ));
    }

    if (insights.isEmpty) {
      insights.add(const AiInsight(
        title: 'Kondisi kendaraan stabil',
        summary: 'Belum ada anomali utama yang terdeteksi dari data OBD-II saat ini.',
        severity: 'low',
      ));
    }

    return insights;
  }
}