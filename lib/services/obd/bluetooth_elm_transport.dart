import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'i_obd_transport.dart';

class BluetoothElmTransport implements IObdTransport {
  final BluetoothDevice device;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  final StreamController<String> _responseController =
  StreamController<String>.broadcast();

  StreamSubscription<List<int>>? _notifySubscription;

  bool _connected = false;

  BluetoothElmTransport(this.device);

  @override
  Stream<String> get responses => _responseController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 10),
      autoConnect: false,
    );

    final services = await device.discoverServices();

    _writeChar = null;
    _notifyChar = null;

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if ((characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) &&
            _writeChar == null) {
          _writeChar = characteristic;
        }

        if ((characteristic.properties.notify ||
            characteristic.properties.indicate) &&
            _notifyChar == null) {
          _notifyChar = characteristic;
        }
      }
    }

    if (_writeChar == null) {
      await device.disconnect();
      throw Exception(
        'Characteristic write Bluetooth tidak ditemukan pada adaptor OBD-II.',
      );
    }

    if (_notifyChar != null) {
      await _notifyChar!.setNotifyValue(true);

      _notifySubscription?.cancel();

      _notifySubscription = _notifyChar!.lastValueStream.listen(
            (value) {
          final text = utf8.decode(
            value,
            allowMalformed: true,
          );

          _responseController.add(text);
        },
      );
    } else {
      await device.disconnect();

      throw Exception(
        'Characteristic notify Bluetooth tidak ditemukan pada adaptor OBD-II.',
      );
    }

    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;

    try {
      await device.disconnect();
    } catch (_) {
      // Ignore disconnect error
    }

    _connected = false;
    _writeChar = null;
    _notifyChar = null;
  }

  @override
  Future<void> send(String command) async {
    if (!_connected || _writeChar == null) {
      throw Exception('Bluetooth OBD belum terhubung.');
    }

    final bytes = utf8.encode('$command\r');

    await _writeChar!.write(
      bytes,
      withoutResponse: _writeChar!.properties.writeWithoutResponse,
    );
  }

  void dispose() {
    _notifySubscription?.cancel();
    _responseController.close();
  }
}