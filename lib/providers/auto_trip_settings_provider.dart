import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoStartObdKey = 'auto_trip_obd_connect';
const _autoStartSpeedKey = 'auto_trip_speed_threshold';

class AutoTripSettings {
  final bool autoStartOnObdConnect;
  final bool autoStartOnSpeedThreshold;

  const AutoTripSettings({
    required this.autoStartOnObdConnect,
    required this.autoStartOnSpeedThreshold,
  });

  AutoTripSettings copyWith({bool? autoStartOnObdConnect, bool? autoStartOnSpeedThreshold}) {
    return AutoTripSettings(
      autoStartOnObdConnect: autoStartOnObdConnect ?? this.autoStartOnObdConnect,
      autoStartOnSpeedThreshold: autoStartOnSpeedThreshold ?? this.autoStartOnSpeedThreshold,
    );
  }
}

final autoTripSettingsProvider =
    StateNotifierProvider<AutoTripSettingsController, AutoTripSettings>((ref) {
  return AutoTripSettingsController();
});

class AutoTripSettingsController extends StateNotifier<AutoTripSettings> {
  AutoTripSettingsController()
      : super(const AutoTripSettings(
          autoStartOnObdConnect: true,
          autoStartOnSpeedThreshold: false,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AutoTripSettings(
      autoStartOnObdConnect: prefs.getBool(_autoStartObdKey) ?? true,
      autoStartOnSpeedThreshold: prefs.getBool(_autoStartSpeedKey) ?? false,
    );
  }

  Future<void> setAutoStartOnObdConnect(bool value) async {
    state = state.copyWith(autoStartOnObdConnect: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartObdKey, value);
  }

  Future<void> setAutoStartOnSpeedThreshold(bool value) async {
    state = state.copyWith(autoStartOnSpeedThreshold: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartSpeedKey, value);
  }
}
