import 'package:intl/intl.dart';

class Formatters {
  static final _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
  static final _date = DateFormat('d MMM yyyy', 'id_ID');
  static final _time = DateFormat('HH:mm', 'id_ID');

  static String dateTime(DateTime value) => _dateTime.format(value);
  static String date(DateTime value) => _date.format(value);
  static String time(DateTime value) => _time.format(value);

  static String duration(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }

  static String number(num value, {int decimals = 0}) {
    return NumberFormat('#,##0${decimals > 0 ? '.${'0' * decimals}' : ''}', 'id_ID')
        .format(value);
  }
}
