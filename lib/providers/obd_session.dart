import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/obd/i_obd_transport.dart';
import 'app_providers.dart';
import 'auto_trip_settings_provider.dart';

class ObdSession {
  ObdSession(this._ref);

  final Ref _ref;

  Future<void> connect(IObdTransport transport) async {
    await disconnect();

    _ref.read(obdTransportProvider.notifier).state = transport;

    try {
      final manager = _ref.read(obdConnectionManagerProvider);
      if (manager == null) throw Exception('Connection manager tidak tersedia');
      await manager.connect();

      final obd = _ref.read(obdProvider);
      if (obd == null) throw Exception('Layanan OBD tidak tersedia');
      await obd.initializeAdapter();
      obd.startPolling();

      await _maybeAutoStartTrip();
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_ref.read(tripRecorderProvider).isRecording) {
      await _ref.read(tripControllerProvider.notifier).stopTrip();
    }

    _ref.read(obdProvider)?.stopPolling();

    final manager = _ref.read(obdConnectionManagerProvider);
    if (manager != null) {
      await manager.disconnect();
    }

    _ref.read(obdTransportProvider.notifier).state = null;
  }

  Future<void> _maybeAutoStartTrip() async {
    final settings = _ref.read(autoTripSettingsProvider);
    if (!settings.autoStartOnObdConnect) return;
    if (_ref.read(tripRecorderProvider).isRecording) return;
    await _ref.read(tripControllerProvider.notifier).startTrip();
  }
}

final obdSessionProvider = Provider<ObdSession>((ref) => ObdSession(ref));