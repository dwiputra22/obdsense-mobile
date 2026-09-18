import '../../models/ecu_info.dart';
import 'obd_connection_manager.dart';
import 'obd_parser.dart';
import 'obd_response_validator.dart';

class EcuInfoService {
  final ObdConnectionManager manager;

  EcuInfoService(this.manager);

  Future<EcuInfo> read() async {
    final vin = await _readAscii('0902', '4902');
    final calibrationId = await _readAscii('0904', '4904');
    final ecuName = await _readAscii('090A', '490A');

    return EcuInfo(vin: vin, calibrationId: calibrationId, ecuName: ecuName);
  }

  Future<String?> _readAscii(String command, String header) async {
    try {
      final response = await manager.queue!.send(command, timeout: const Duration(seconds: 4));
      if (!ObdResponseValidator.isValid(response)) return null;

      final s = ObdParser.sanitize(response);
      final idx = s.indexOf(header);
      if (idx == -1) return null;

      var dataHex = s.substring(idx + header.length);
      if (dataHex.length.isOdd) {
        dataHex = dataHex.substring(2);
      }

      final buffer = StringBuffer();
      for (int i = 0; i + 1 < dataHex.length; i += 2) {
        final byteVal = int.tryParse(dataHex.substring(i, i + 2), radix: 16);
        if (byteVal == null) continue;
        if (byteVal >= 0x20 && byteVal <= 0x7E) {
          buffer.writeCharCode(byteVal);
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
