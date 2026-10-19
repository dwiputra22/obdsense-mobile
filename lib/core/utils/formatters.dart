import 'package:intl/intl.dart';

import '../i18n/app_language.dart';

class Formatters {
  static String get _locale => AppLanguage.current == AppLang.en ? 'en_US' : 'id_ID';

  static String dateTime(DateTime value) => DateFormat('d MMM yyyy, HH:mm', _locale).format(value);
  static String date(DateTime value) => DateFormat('d MMM yyyy', _locale).format(value);
  static String time(DateTime value) => DateFormat('HH:mm', _locale).format(value);

  static String duration(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    // Indonesia: j = jam, m = menit. Inggris: h = hours, m = minutes.
    final hourUnit = AppLanguage.current == AppLang.en ? 'h' : 'j';
    if (h > 0) return '$h$hourUnit ${m}m';
    return '${m}m';
  }

  static String number(num value, {int decimals = 0}) {
    return NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}', _locale).format(value);
  }
}