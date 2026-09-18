class ObdCommand {
  static const reset = 'ATZ';
  static const echoOff = 'ATE0';
  static const lineFeedOff = 'ATL0';
  static const spacesOff = 'ATS0';
  static const headersOff = 'ATH0';
  static const autoProtocol = 'ATSP0';

  static const rpm = '010C';
  static const speed = '010D';
  static const coolantTemp = '0105';
  static const engineLoad = '0104';
  static const throttlePosition = '0111';
  static const intakeTemp = '010F';
  static const voltage = 'ATRV';
  static const readDtc = '03';
  static const maf = '0110';
  static const fuelRate = '015E';
  static const fuelLevel = '012F';
}