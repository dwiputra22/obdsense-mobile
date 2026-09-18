class AppConstants {
  static const String apiBaseUrl = 'https://rushsense-api-production.up.railway.app/api';

  static const Duration telemetryPollInterval = Duration(seconds: 2);
  static const Duration obdCommandTimeout = Duration(seconds: 3);
  static const Duration obdReconnectInterval = Duration(seconds: 5);

  static const String activeVehicleIdKey = 'active_vehicle_id';
  static const String activeVinKey = 'active_vin';

  static const String deviceApiKey = 'XXXAAAQQQWWWBBB';

  static const double highCoolantTempC = 100;
  static const double lowBatteryVoltage = 12.3;
}
