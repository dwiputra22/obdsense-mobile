import 'dart:async';
import 'i_obd_transport.dart';
import 'obd_command_queue.dart';

class ObdConnectionManager {
  final IObdTransport transport;
  ObdCommandQueue? queue;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

  ObdConnectionManager(this.transport);

  Future<void> connect() async {
    _manualDisconnect = false;
    await transport.connect();
    queue = ObdCommandQueue(transport);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    queue?.dispose();
    await transport.disconnect();
  }

  void startAutoReconnect({
    Duration interval = const Duration(seconds: 5),
  }) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(interval, (_) async {
      if (_manualDisconnect) return;
      if (!transport.isConnected) {
        try {
          await transport.connect();
          queue?.dispose();
          queue = ObdCommandQueue(transport);
        } catch (_) {}
      }
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    queue?.dispose();
  }
}