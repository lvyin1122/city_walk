import 'package:intl/intl.dart';
// Utility functions for walk history and summary

String formatUserAddress(dynamic userAddressRaw) {
  if (userAddressRaw == null) return '';
  final addressParts = userAddressRaw.toString().split(',');
  if (addressParts.length >= 3) {
    return '${addressParts[1].trim()}, ${addressParts[2].trim()}';
  } else if (addressParts.length == 2) {
    return '${addressParts[0].trim()}, ${addressParts[1].trim()}';
  } else if (addressParts.length == 1) {
    return addressParts[0].trim();
  }
  return '';
}

String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '$hours:${remainingMinutes.toString().padLeft(2, '0')}';
}

String formatDayOfWeek(DateTime? date) {
  if (date == null) return 'N/A';
  return ['SUN', 'MON', 'TUES', 'WED', 'THU', 'FRI', 'SAT'][date.weekday % 7];
}

String formatDateStr(DateTime? date) {
  if (date == null) return 'N/A';
  return '${date.month}/${date.day}';
}

String formatTimeStr(DateTime? date) {
  if (date == null) return 'N/A';
  return DateFormat('h:mm a').format(date.toLocal());
} 