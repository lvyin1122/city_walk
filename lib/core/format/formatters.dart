import 'package:intl/intl.dart';

/// Formats an elapsed time as `m:ss`, or `h:mm:ss` from one hour up.
String formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// Formats a walking time estimate, for example `45 分钟` or `1 小时 20 分钟`.
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分钟';
}

/// Formats a distance in kilometres with one decimal, for example `1.2 km`.
String formatKilometers(double kilometers) =>
    '${kilometers.toStringAsFixed(1)} km';

const List<String> _weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/// Day of the week of [date] in the device's time zone, for example `周三`.
String formatDayOfWeek(DateTime? date) {
  if (date == null) return '--';
  return _weekdays[date.toLocal().weekday % 7];
}

/// Month and day of [date] in the device's time zone, for example `10/8`.
String formatMonthDay(DateTime? date) {
  if (date == null) return '--';
  final local = date.toLocal();
  return '${local.month}/${local.day}';
}

/// Time of day of [date] in the device's time zone, for example `14:30`.
String formatTimeOfDay(DateTime? date) {
  if (date == null) return '--';
  return DateFormat('HH:mm').format(date.toLocal());
}

/// Shortens a full postal address to its district and city parts.
String formatUserAddress(Object? rawAddress) {
  if (rawAddress == null) return '';
  final parts = rawAddress.toString().split(',').map((part) => part.trim());
  final list = parts.where((part) => part.isNotEmpty).toList();
  if (list.length >= 3) return '${list[1]}, ${list[2]}';
  return list.join(', ');
}
