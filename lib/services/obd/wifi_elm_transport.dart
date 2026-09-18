import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'i_obd_transport.dart';

class WifiElmTransport implements IObdTransport {
  final String host;
  final int port;

  Socket? _socket;
  final StreamController<String> _responseController = StreamController.broadcast();

  WifiElmTransport({
    required this.host,
    this.port = 35000,
  });

  @override
  Stream<String> get responses => _responseController.stream;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    _socket!.listen(
          (data) {
        final text = utf8.decode(data, allowMalformed: true);
        _responseController.add(text);
      },
      onDone: () {
        _socket = null;
      },
      onError: (_) {
        _socket = null;
      },
    );
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  @override
  Future<void> send(String command) async {
    if (_socket == null) {
      throw Exception('OBD Wi-Fi belum terhubung');
    }
    _socket!.write('$command\r');
    await _socket!.flush();
  }

  void dispose() {
    _responseController.close();
  }
}