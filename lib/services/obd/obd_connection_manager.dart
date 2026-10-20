import 'dart:async';
import 'i_obd_transport.dart';
import 'obd_command_queue.dart';

enum ObdLinkStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ObdConnectionManager {
  final IObdTransport transport;
  ObdCommandQueue? queue;

  Future<void> Function()? onReconnected;

  ObdLinkStatus _status = ObdLinkStatus.disconnected;
  final StreamController<ObdLinkStatus> _statusController =
      StreamController<ObdLinkStatus>.broadcast();
  StreamSubscription<bool>? _linkSub;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  bool _reconnectBusy = false;
  bool _disposed = false;

  ObdConnectionManager(this.transport);

  ObdLinkStatus get status => _status;
  Stream<ObdLinkStatus> get statusStream => _statusController.stream;

  bool get isConnected => _status == ObdLinkStatus.connected && transport.isConnected;

  DateTime? get lastReplyAt => queue?.lastReplyAt;

  void _setStatus(ObdLinkStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  void _listenLink() {
    _linkSub?.cancel();
    _linkSub = transport.connectionChanges.listen((up) {
      if (!up) reportLinkLost();
    });
  }

  Future<void> connect() async {
    _manualDisconnect = false;
    _setStatus(ObdLinkStatus.connecting);
    try {
      await transport.connect();
      queue?.dispose();
      queue = ObdCommandQueue(transport);
      _listenLink();
      _setStatus(ObdLinkStatus.connected);
    } catch (_) {
      _setStatus(ObdLinkStatus.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _linkSub?.cancel();
    _linkSub = null;
    queue?.dispose();
    try {
      await transport.disconnect();
    } catch (_) {}
    _setStatus(ObdLinkStatus.disconnected);
  }

  void reportLinkLost() {
    if (_manualDisconnect || _disposed) return;
    if (_status != ObdLinkStatus.connected) return;

    queue?.dispose();

    if (transport.supportsAutoReconnect) {
      _setStatus(ObdLinkStatus.reconnecting);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (_) => _attemptReconnect());
    } else {
      _setStatus(ObdLinkStatus.disconnected);
      unawaited(() async {
        try {
          await transport.disconnect();
        } catch (_) {}
      }());
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnectBusy || _manualDisconnect || _disposed) return;
    if (_status != ObdLinkStatus.reconnecting) return;
    _reconnectBusy = true;
    try {
      try {
        await transport.disconnect();
      } catch (_) {}
      await transport.connect();
      if (_manualDisconnect || _disposed) {
        await transport.disconnect();
        return;
      }
      queue?.dispose();
      queue = ObdCommandQueue(transport);
      _listenLink();
      await onReconnected?.call();
      if (_manualDisconnect || _disposed) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _setStatus(ObdLinkStatus.connected);
    } catch (_) {
      try {
        await transport.disconnect();
      } catch (_) {}
    } finally {
      _reconnectBusy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _linkSub?.cancel();
    queue?.dispose();
    if (!_statusController.isClosed) _statusController.close();
  }
}