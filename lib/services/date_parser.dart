/// Lightweight, offline, rule-based deadline detector.
/// No AI/network call — just pattern matching, so results are
/// "best effort" for common phrasings, not full natural-language parsing.
class DateParser {
  static const _weekdays = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun',
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
  ];

  /// Tries to find a date mentioned in [text]. Returns null if nothing
  /// date-like is found. Time is always set to end of that day (23:59)
  /// so a same-day deadline doesn't read as already overdue.
  static DateTime? extract(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;
    final now = DateTime.now();

    DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

    if (lower.contains('today')) return endOfDay(now);
    if (lower.contains('tomorrow')) {
      return endOfDay(now.add(const Duration(days: 1)));
    }

    // "next monday", "on friday", "this saturday"
    for (var i = 0; i < _weekdays.length; i++) {
      final name = _weekdays[i];
      if (lower.contains(name)) {
        final target = i + 1; // DateTime.weekday: Mon=1..Sun=7
        var diff = target - now.weekday;
        if (diff <= 0) diff += 7;
        if (lower.contains('next $name') && diff <= 7) diff += 7;
        return endOfDay(now.add(Duration(days: diff)));
      }
    }

    // "15 oct", "15 october", "15th of october", "oct 15"
    final dayMonth = RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:of\s*)?([a-zA-Z]{3,9})\b');
    final monthDay = RegExp(r'\b([a-zA-Z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?\b');
    final numeric = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b');

    int? monthIndex(String token) {
      final t = token.toLowerCase().substring(0, token.length >= 3 ? 3 : token.length);
      final idx = _months.indexOf(t);
      return idx == -1 ? null : idx + 1;
    }

    for (final m in dayMonth.allMatches(lower)) {
      final mi = monthIndex(m.group(2)!);
      final day = int.tryParse(m.group(1)!);
      if (mi != null && day != null && in1to31(day)) {
        return _resolveYear(now, mi, day);
      }
    }
    for (final m in monthDay.allMatches(lower)) {
      final mi = monthIndex(m.group(1)!);
      final day = int.tryParse(m.group(2)!);
      if (mi != null && day != null && in1to31(day)) {
        return _resolveYear(now, mi, day);
      }
    }
    final n = numeric.firstMatch(lower);
    if (n != null) {
      final a = int.tryParse(n.group(1)!);
      final b = int.tryParse(n.group(2)!);
      final yearStr = n.group(3);
      if (a != null && b != null && b >= 1 && b <= 12 && in1to31(a)) {
        // Interpreted as day/month (matches the app's DateFormat.yMMMd elsewhere
        // being locale-aware; this assumes day-first input, common in India).
        var year = now.year;
        if (yearStr != null) {
          final y = int.parse(yearStr);
          year = y < 100 ? 2000 + y : y;
        }
        try {
          return endOfDay(DateTime(year, b, a));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static bool in1to31(int d) => d >= 1 && d <= 31;

  static DateTime _resolveYear(DateTime now, int month, int day) {
    var year = now.year;
    try {
      var d = DateTime(year, month, day, 23, 59);
      if (d.isBefore(now)) d = DateTime(year + 1, month, day, 23, 59);
      return d;
    } catch (_) {
      return DateTime(year, month, day, 23, 59);
    }
  }
}
