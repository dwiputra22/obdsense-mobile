import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/anomaly.dart';

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
    const androidDetails = AndroidNotificationDetails(
      'high_temp_channel',
      'High Temperature Alerts',
      channelDescription: 'Peringatan suhu mesin tinggi',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      1001,
      'Suhu Mesin Tinggi',
      'Suhu mesin terdeteksi ${tempC.toStringAsFixed(0)}°C. Segera pantau kondisi kendaraan.',
      details,
    );
  }

  Future<void> showAnomalyAlert(Anomaly anomaly) async {
    const androidDetails = AndroidNotificationDetails(
      'anomaly_channel',
      'Anomaly Alerts',
      channelDescription: 'Peringatan penyimpangan dari kebiasaan normal mobil',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      2000 + anomaly.sensorKey.hashCode % 1000,
      '${anomaly.label} Tidak Biasa',
      'Nilai saat ini ${anomaly.actualValue.toStringAsFixed(1)} - biasanya sekitar '
          '${anomaly.expectedMean.toStringAsFixed(1)} untuk mobil ini.',
      details,
    );
  }

  Future<void> showNewDtcAlert(List<String> newCodes) async {
    const androidDetails = AndroidNotificationDetails(
      'dtc_channel',
      'DTC Alerts',
      channelDescription: 'Peringatan kode error baru terdeteksi',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      3000,
      'Kode Error Baru Terdeteksi',
      newCodes.join(', '),
      details,
    );
  }
}
