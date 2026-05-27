// lib/core/utils/date_utils.dart
import 'package:intl/intl.dart';

class DateHelper {
  static String format(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDisplay(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatMonth(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM yyyy').format(date);
  }

  static String today() => format(DateTime.now());

  static DateTime? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static int daysUntil(DateTime deadline) {
    final now = DateTime.now();
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    final n = DateTime(now.year, now.month, now.day);
    return d.difference(n).inDays;
  }

  static String deadlineLabel(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final date = parse(dateStr);
    if (date == null) return dateStr;
    final diff = daysUntil(date);
    if (diff < 0) return 'Overdue ${diff.abs()}d';
    if (diff == 0) return 'Due Today';
    if (diff <= 2) return '${diff}d left';
    if (diff <= 7) return '${diff}d left';
    return '${diff}d';
  }

  static List<String> getMonthList() {
    final months = <String>[];

    for (int year = 2026; year <= 2029; year++) {
      for (int month = 1; month <= 12; month++) {
        months.add(
          '$year-${month.toString().padLeft(2, '0')}',
        );
      }
    }

    return months;
  }
}
