import 'package:intl/intl.dart';

class DateTimeUtils {
  // Format date to string
  static String formatDate(DateTime date, {String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern).format(date.toLocal());
  }

  // Format date with time
  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal());
  }

  // Format to readable date
  static String formatReadableDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date.toLocal());
  }

  // Format to relative time (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Check if date is today
  static bool isToday(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year && local.month == now.month && local.day == now.day;
  }

  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final local = date.toLocal();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
  }
}
