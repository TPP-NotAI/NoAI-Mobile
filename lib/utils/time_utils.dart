String humanReadableTime(String timestamp) {
  DateTime? dt;

  // Try ISO-8601 parse
  dt = DateTime.tryParse(timestamp);

  // Try parsing as milliseconds / seconds since epoch
  if (dt == null) {
    try {
      final n = int.parse(timestamp);
      dt = (timestamp.length >= 13)
          ? DateTime.fromMillisecondsSinceEpoch(n)
          : DateTime.fromMillisecondsSinceEpoch(n * 1000);
    } catch (_) {
      // leave dt null
    }
  }

  if (dt == null) return timestamp; // fallback to original

  // Convert to local timezone so all comparisons and formatting use the viewer's time
  dt = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';

  // Format as "Mon D" or "Mon D, YYYY" if different year
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[dt.month - 1];
  final day = dt.day;
  if (dt.year == now.year) {
    return '$month $day';
  } else {
    return '$month $day, ${dt.year}';
  }
}
