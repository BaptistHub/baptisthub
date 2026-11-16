const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  final m = _months[d.month - 1];
  return d.year == now.year ? '$m ${d.day}' : '$m ${d.day}, ${d.year}';
}

String formatRuntime(double? minutes) {
  if (minutes == null || minutes <= 0) return '';
  final total = minutes.round();
  if (total < 60) return '$total min';
  final h = total ~/ 60, m = total % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatClock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k < 10 ? k.toStringAsFixed(1).replaceAll('.0', '') : k.round()}K';
  }
  final m = n / 1000000;
  return '${m < 10 ? m.toStringAsFixed(1).replaceAll('.0', '') : m.round()}M';
}

String plural(int n, String word) =>
    '${formatCount(n)} $word${n == 1 ? '' : 's'}';

/// "Sermon · Nov 9 · 56 min" style meta lines, skipping empty parts.
String joinMeta(Iterable<String?> parts) =>
    parts.where((p) => p != null && p.isNotEmpty).join('  ·  ');
