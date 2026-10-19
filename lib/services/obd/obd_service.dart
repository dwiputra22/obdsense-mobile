import 'dart:async';
import '../../models/dtc_code.dart';
import '../../models/telemetry_data.dart';
import '../trips/fuel_efficiency_calculator.dart';
import 'obd_command.dart';
import 'obd_connection_manager.dart';
import 'obd_parser.dart';
import 'dtc_parser.dart';
import 'obd_response_validator.dart';
import 'pid_support_checker.dart';
import 'pid_table.dart';

class ObdService {
  final ObdConnectionManager manager;
  final StreamController<TelemetryData> _telemetryController = StreamController.broadcast();
  final StreamController<Map<String, double>> _extraSensorsController =
  StreamController.broadcast();
  Timer? _pollTimer;
  Timer? _extendedPollTimer;
  Timer? _auxPollTimer;
  bool _telemetryCycleRunning = false;
  bool _extendedCycleRunning = false;
  int _auxIndex = 0;
  int _extendedIndex = 0;

  double _rpm = 0;
  double _speed = 0;
  double _coolant = 0;
  double _voltage = 0;
  double _load = 0;
  double _throttle = 0;
  double _intake = 0;

  double? _maf;
  double? _fuelRateDirect;
  double _fuelLevel = 0;
  int _fuelRateMissCount = 0;
  bool _fuelRatePidUnsupported = false;

  Set<String> supportedPids = {};
  List<PidDefinition> availableExtendedPids = [];
  final Map<String, double> _extraSensorReadings = {};

  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  Stream<Map<String, double>> get extraSensorsStream => _extraSensorsController.stream;

  ObdService(this.manager);

  Future<void> initializeAdapter() async {
    await manager.queue!.send(ObdCommand.reset, timeout: const Duration(seconds: 4));
    await Future.delayed(const Duration(milliseconds: 800));
    await manager.queue!.send(ObdCommand.echoOff);
    await manager.queue!.send(ObdCommand.lineFeedOff);
    await manager.queue!.send(ObdCommand.spacesOff);
    await manager.queue!.send(ObdCommand.headersOff);
    await manager.queue!.send(ObdCommand.autoProtocol, timeout: const Duration(seconds: 4));

    await _discoverSupportedPids();
  }

  Future<void> _discoverSupportedPids() async {
    final supported = <String>{};

    try {
      final r1 = await manager.queue!.send('0100', timeout: const Duration(seconds: 3));
      if (!ObdResponseValidator.isValid(r1)) return;
      final group1 = PidSupportChecker.parseBitmask(r1, '4100', 0x00);
      supported.addAll(group1);

      if (PidSupportChecker.hasNextGroup(group1, 0x20)) {
        final r2 = await manager.queue!.send('0120', timeout: const Duration(seconds: 3));
        if (ObdResponseValidator.isValid(r2)) {
          final group2 = PidSupportChecker.parseBitmask(r2, '4120', 0x20);
          supported.addAll(group2);

          if (PidSupportChecker.hasNextGroup(group2, 0x40)) {
            final r3 = await manager.queue!.send('0140', timeout: const Duration(seconds: 3));
            if (ObdResponseValidator.isValid(r3)) {
              supported.addAll(PidSupportChecker.parseBitmask(r3, '4140', 0x40));
            }
          }
        }
      }
    } catch (_) {
      // Biarkan supportedPids apa adanya sejauh berhasil didapat.
    }

    supportedPids = supported;
    availableExtendedPids = PidTable.extended.where((p) => supported.contains(p.pid)).toList();
  }

  void startPolling() {
    _pollTimer?.cancel();
    _auxPollTimer?.cancel();
    _extendedPollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (_telemetryCycleRunning || manager.queue == null || !manager.isConnected) return;
      _telemetryCycleRunning = true;
      try {
        await _readPid(ObdCommand.rpm, '410C', (r) => _rpm = ObdParser.parseRpm(r) ?? _rpm,
            timeout: const Duration(milliseconds: 900));
        await _readPid(ObdCommand.speed, '410D', (r) => _speed = ObdParser.parseSpeed(r) ?? _speed,
            timeout: const Duration(milliseconds: 900));
        final fuelRate = _fuelRateDirect ?? FuelEfficiencyCalculator.fuelRateFromMaf(_maf) ?? 0;
        if (!_telemetryController.isClosed) {
          _telemetryController.add(TelemetryData(
            rpm: _rpm,
            speed: _speed,
            coolantTempC: _coolant,
            batteryVoltage: _voltage,
            engineLoad: _load,
            throttlePosition: _throttle,
            intakeTempC: _intake,
            timestamp: DateTime.now(),
            fuelRateLph: fuelRate,
            fuelLevelPercent: _fuelLevel,
          ));
        }
      } finally {
        _telemetryCycleRunning = false;
      }
    });

    _auxPollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      if (_telemetryCycleRunning || manager.queue == null || !manager.isConnected) return;
      final tasks = <Future<void> Function()>[
            () => _readPid(ObdCommand.coolantTemp, '4105', (r) => _coolant = ObdParser.parseCoolantTempC(r) ?? _coolant),
            () => _readPid(ObdCommand.engineLoad, '4104', (r) => _load = ObdParser.parseEngineLoad(r) ?? _load),
            () => _readPid(ObdCommand.throttlePosition, '4111', (r) => _throttle = ObdParser.parseThrottle(r) ?? _throttle),
            () => _readPid(ObdCommand.intakeTemp, '410F', (r) => _intake = ObdParser.parseIntakeTempC(r) ?? _intake),
            () => _readPid(ObdCommand.maf, '4110', (r) => _maf = ObdParser.parseMaf(r) ?? _maf),
            () => _readPid(ObdCommand.fuelLevel, '412F', (r) => _fuelLevel = ObdParser.parseFuelLevel(r) ?? _fuelLevel),
        if (!_fuelRatePidUnsupported) () async {
          await _readPid(ObdCommand.fuelRate, '415E', (r) => _fuelRateDirect = ObdParser.parseFuelRate(r));
          if (_fuelRateDirect == null) {
            _fuelRateMissCount++;
            if (_fuelRateMissCount >= 3) _fuelRatePidUnsupported = true;
          } else {
            _fuelRateMissCount = 0;
          }
        },
            () async {
          try {
            final response = await manager.queue!.send(ObdCommand.voltage, timeout: const Duration(milliseconds: 900));
            if (ObdResponseValidator.isValid(response)) _voltage = ObdParser.parseVoltage(response) ?? _voltage;
          } catch (_) {}
        },
      ];
      if (_auxIndex >= tasks.length) _auxIndex = 0;
      await tasks[_auxIndex++]();
    });

    if (availableExtendedPids.isNotEmpty) {
      _extendedPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (_extendedCycleRunning || _telemetryCycleRunning || manager.queue == null || !manager.isConnected) return;
        _extendedCycleRunning = true;
        try {
          if (_extendedIndex >= availableExtendedPids.length) _extendedIndex = 0;
          final pidDef = availableExtendedPids[_extendedIndex++];
          try {
            final response = await manager.queue!.send('01${pidDef.pid}', timeout: const Duration(milliseconds: 1100));
            if (ObdResponseValidator.isValid(response)) {
              final bytes = _extractDataBytes(response, pidDef.pid, pidDef.expectedBytes);
              if (bytes != null) _extraSensorReadings[pidDef.pid] = pidDef.decode(bytes);
            }
          } catch (_) {
            // Satu PID gagal tidak boleh menghentikan seluruh siklus.
          }
          if (!_extraSensorsController.isClosed) _extraSensorsController.add(Map.unmodifiable(_extraSensorReadings));
        } finally {
          _extendedCycleRunning = false;
        }
      });
    }
  }

  List<int>? _extractDataBytes(String raw, String pidHex, int expectedBytes) {
    final s = ObdParser.sanitize(raw);
    final header = '41$pidHex';
    final idx = s.indexOf(header);
    if (idx == -1) return null;

    final dataStart = idx + header.length;
    final dataEnd = dataStart + (expectedBytes * 2);
    if (s.length < dataEnd) return null;

    final bytes = <int>[];
    for (int i = dataStart; i < dataEnd; i += 2) {
      bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<void> _readPid(
      String command,
      String expectedHeader,
      void Function(String raw) onSuccess, {
        Duration timeout = const Duration(milliseconds: 1100),
      }) async {
    try {
      final response = await manager.queue!.send(command, timeout: timeout);
      if (!ObdResponseValidator.isValid(response)) return;
      if (!ObdResponseValidator.containsPidResponse(response, expectedHeader)) return;
      onSuccess(response);
    } catch (_) {}
  }

  Future<List<DtcCode>> readDtc() async {
    try {
      final response = await manager.queue!.send(ObdCommand.readDtc);
      if (!ObdResponseValidator.isValid(response)) return [];
      return DtcParser.parse(response);
    } catch (_) {
      return [];
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _auxPollTimer?.cancel();
    _extendedPollTimer?.cancel();
    _telemetryCycleRunning = false;
    _extendedCycleRunning = false;
  }

  void dispose() {
    stopPolling();
    _telemetryController.close();
    _extraSensorsController.close();
  }
}