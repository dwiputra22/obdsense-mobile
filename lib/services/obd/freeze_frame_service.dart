import '../../models/freeze_frame_data.dart';
import 'dtc_parser.dart';
import 'obd_connection_manager.dart';
import 'obd_parser.dart';
import 'obd_response_validator.dart';

/// CATATAN yang belum bisa saya pastikan 100% tanpa uji di adapter
/// fisik: format request Mode 02 di beberapa referensi ditulis dengan
/// byte nomor frame eksplisit (mis. "020C00" = mode 02, PID 0C, frame
/// 0), sementara di ELM327 lama kadang cukup "020C" (frame 0 default).
/// Di bawah saya pakai format dengan frame eksplisit (lebih sesuai spec
/// lengkap) - kalau ternyata ELM327/adapter Anda tidak merespons dengan
/// format ini, kabari saya untuk saya sesuaikan ke format tanpa byte
/// frame.
class FreezeFrameService {
  final ObdConnectionManager manager;

  FreezeFrameService(this.manager);

  Future<FreezeFrameData?> read() async {
    final dtcResponse = await manager.queue!.send('0202');
    if (!ObdResponseValidator.isValid(dtcResponse)) return null;

    final s = ObdParser.sanitize(dtcResponse);
    final idx = s.indexOf('4202');
    if (idx == -1 || s.length < idx + 8) return null;

    final dtcHex = s.substring(idx + 4, idx + 8);
    final dtcCode = DtcParser.decodeSingleDtc(dtcHex);
    if (dtcCode == null) return null; // 0000 = tidak ada freeze frame

    final rpm = await _readFrame('0C', 2, (b) => ((b[0] * 256) + b[1]) / 4);
    final speed = await _readFrame('0D', 1, (b) => b[0].toDouble());
    final coolant = await _readFrame('05', 1, (b) => (b[0] - 40).toDouble());
    final load = await _readFrame('04', 1, (b) => b[0] * 100 / 255);
    final throttle = await _readFrame('11', 1, (b) => b[0] * 100 / 255);
    final intake = await _readFrame('0F', 1, (b) => (b[0] - 40).toDouble());
    final fuelLevel = await _readFrame('2F', 1, (b) => b[0] * 100 / 255);

    return FreezeFrameData(
      triggeringDtc: dtcCode,
      rpm: rpm,
      speed: speed,
      coolantTempC: coolant,
      engineLoad: load,
      throttlePosition: throttle,
      intakeTempC: intake,
      fuelLevelPercent: fuelLevel,
    );
  }

  Future<double?> _readFrame(
    String pidHex,
    int expectedBytes,
    double Function(List<int>) decode,
  ) async {
    try {
      final response = await manager.queue!.send('02$pidHex' '00');
      if (!ObdResponseValidator.isValid(response)) return null;

      final s = ObdParser.sanitize(response);
      final header = '42$pidHex';
      final idx = s.indexOf(header);
      if (idx == -1) return null;

      final dataStart = idx + header.length;
      final frameByteEnd = dataStart + 2;
      final dataEnd = frameByteEnd + (expectedBytes * 2);
      if (s.length < dataEnd) return null;

      final bytes = <int>[];
      for (int i = frameByteEnd; i < dataEnd; i += 2) {
        bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
      }
      return decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
