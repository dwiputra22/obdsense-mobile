import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flserial/flserial.dart';
import 'package:flserial/serial_scanner.dart';
import 'i_obd_transport.dart';

class UsbElmTransport implements IObdTransport {
  final String portName;
  final FlSerial _serial = FlSerial();
  final StreamController<String> _responseController = StreamController.broadcast();
  StreamSubscription? _dataSub;
  bool _isOpen = false;

  UsbElmTransport(this.portName);

  static Future<List<SerialPortInfo>> listPorts() {
    return FlSerial.availablePorts();
  }

  @override
  Stream<String> get responses => _responseController.stream;

  @override
  bool get isConnected => _isOpen;

  @override
  Future<void> connect() async {
    final config = SerialConfig(
      baudRate: 38400,    // Default pabrik tersering untuk chip ELM327
      dataBits: 8,        // Menggantikan setByteSize8()
      stopBits: 1,        // Menggantikan setStopBits1()
      parity: 0,          // 0 = None (Menggantikan setBitParityNone())
      flowControl: 0,     // 0 = None (Menggantikan setFlowControlNone())
    );

    await _serial.open(portName, config);

    _dataSub = _serial.events.listen((event) {
      if (event.type == SerialEventType.data) {
        final Uint8List rawData = event.data as Uint8List;
        if (rawData.isNotEmpty) {
          _responseController.add(
            utf8.decode(rawData, allowMalformed: true),
          );
        }
      }
    });

    _isOpen = true;
  }

  @override
  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    await _serial.close();
    _serial.dispose();
    _isOpen = false;
  }

  @override
  Future<void> send(String command) async {
    if (!_isOpen) {
      throw StateError('Belum terhubung ke adapter OBD-II via USB.');
    }
    final data = Uint8List.fromList(utf8.encode('$command\r'));
    _serial.write(data);
  }
}

