import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'i_obd_transport.dart';

class WifiElmTransport implements IObdTransport {
  final String host;
  final int port;

  Socket? _socket;
  final StreamController<String> _responseController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();

  WifiElmTransport({
    required this.host,
    this.port = 35000,
  });

  @override
  Stream<String> get responses => _responseController.stream;

  @override
  Stream<bool> get connectionChanges => _connectionController.stream;

  @override
  bool get isConnected => _socket != null;

  @override
  bool get supportsAutoReconnect => true;

  void _markClosed(Socket socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    if (!_connectionController.isClosed) _connectionController.add(false);
  }

  @override
  Future<void> connect() async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    _socket = socket;
    socket.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        _responseController.add(text);
      },
      onDone: () => _markClosed(socket),
      onError: (_) => _markClosed(socket),
      cancelOnError: true,
    );
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    try {
      socket?.destroy();
    } catch (_) {}
  }

  @override
  Future<void> send(String command) async {
    final socket = _socket;
    if (socket == null) {
      throw Exception('OBD Wi-Fi belum terhubung');
    }
    socket.write('$command\r');
    await socket.flush();
  }

  void dispose() {
    _responseController.close();
    _connectionController.close();
  }
}