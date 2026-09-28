import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'data/local/local_storage_service.dart';
import 'providers/app_providers.dart';
import 'services/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting('id_ID', null);

  final storage = LocalStorageService();
  await storage.init();

  final notifications = NotificationService();
  await notifications.init();

  final activeVehicleId = await storage.getActiveVehicleId() ?? 1;

  runApp(
    ProviderScope(
      overrides: [
        activeVehicleIdProvider.overrideWith((ref) => activeVehicleId),
      ],
      child: const RushSenseApp(),
    ),
  );
}
