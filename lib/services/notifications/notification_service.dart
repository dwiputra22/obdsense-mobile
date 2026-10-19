import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/anomaly.dart';
import '../../core/i18n/translations.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: iOS);
    await _plugin.initialize(settings);
  }

  Future<void> showHighTempAlert(double tempC) async {
    final androidDetails = AndroidNotificationDetails(
      'high_temp_channel',
      tr('High Temperature Alerts'),
      channelDescription: tr('Peringatan suhu mesin tinggi'),
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      1001,
      tr('Suhu Mesin Tinggi'),
      tr('Suhu mesin terdeteksi ${tempC.toStringAsFixed(0)}°C. Segera pantau kondisi kendaraan.'),
      details,
    );
  }

  Future<void> showAnomalyAlert(Anomaly anomaly) async {
    final androidDetails = AndroidNotificationDetails(
      'anomaly_channel',
      tr('Anomaly Alerts'),
      channelDescription: tr('Peringatan penyimpangan dari kebiasaan normal mobil'),
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      2000 + anomaly.sensorKey.hashCode % 1000,
      tr('${anomaly.label} Tidak Biasa'),
      tr('Nilai saat ini ${anomaly.actualValue.toStringAsFixed(1)} - biasanya sekitar '
          '${anomaly.expectedMean.toStringAsFixed(1)} untuk mobil ini.'),
      details,
    );
  }

  Future<void> showNewDtcAlert(List<String> newCodes) async {
    final androidDetails = AndroidNotificationDetails(
      'dtc_channel',
      tr('DTC Alerts'),
      channelDescription: tr('Peringatan kode error baru terdeteksi'),
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      3000,
      tr('Kode Error Baru Terdeteksi'),
      newCodes.join(', '),
      details,
    );
  }
}