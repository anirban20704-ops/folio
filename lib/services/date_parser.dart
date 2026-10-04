/// A plain hour/minute pair - kept dependency-free (no Flutter import)
/// since this file is a pure-Dart, offline service.
class ParsedTime {
  final int hour;
  final int minute;
  const ParsedTime(this.hour, this.minute);
}

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

  /// Tries to find a date and/or time mentioned in [text] and combines them:
  /// - date + time found  -> that exact moment ("tomorrow 5pm")
  /// - date only found    -> end of that day, 23:59 ("tomorrow")
  /// - time only found    -> today at that time, or tomorrow if it's
  ///                         already past that time today ("5pm")
  /// - neither found      -> null
  static DateTime? extract(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return null;
    final now = DateTime.now();

    final time = extractTime(lower);
    final datePart = _extractDatePart(lower, now);

    if (datePart == null && time == null) return null;

    if (datePart != null) {
      final h = time?.hour ?? 23;
      final m = time?.minute ?? 59;
      return DateTime(datePart.year, datePart.month, datePart.day, h, m);
    }

    final candidate =
        DateTime(now.year, now.month, now.day, time!.hour, time.minute);
    return candidate.isBefore(now)
        ? candidate.add(const Duration(days: 1))
        : candidate;
  }

  /// Returns just the calendar date (year/month/day, time zeroed) mentioned
  /// in [lower], or null if no date phrase is found.
  static DateTime? _extractDatePart(String lower, DateTime now) {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    if (lower.contains('today')) return dateOnly(now);
    if (lower.contains('tomorrow')) {
      return dateOnly(now.add(const Duration(days: 1)));
    }

    // "next monday", "on friday", "this saturday"
    for (var i = 0; i < _weekdays.length; i++) {
      final name = _weekdays[i];
      if (lower.contains(name)) {
        final target = i + 1; // DateTime.weekday: Mon=1..Sun=7
        var diff = target - now.weekday;
        if (diff <= 0) diff += 7;
        if (lower.contains('next $name') && diff <= 7) diff += 7;
        return dateOnly(now.add(Duration(days: diff)));
      }
    }

    // "15 oct", "15 october", "15th of october", "oct 15"
    final dayMonth = RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:of\s*)?([a-zA-Z]{3,9})\b');
    final monthDay = RegExp(r'\b([a-zA-Z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?\b');
    final numeric = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b');

    int? monthIndex(String token) {
      final t =
          token.toLowerCase().substring(0, token.length >= 3 ? 3 : token.length);
      final idx = _months.indexOf(t);
      return idx == -1 ? null : idx + 1;
    }

    for (final m in dayMonth.allMatches(lower)) {
      final mi = monthIndex(m.group(2)!);
      final day = int.tryParse(m.group(1)!);
      if (mi != null && day != null && in1to31(day)) {
        return dateOnly(_resolveYear(now, mi, day));
      }
    }
    for (final m in monthDay.allMatches(lower)) {
      final mi = monthIndex(m.group(1)!);
      final day = int.tryParse(m.group(2)!);
      if (mi != null && day != null && in1to31(day)) {
        return dateOnly(_resolveYear(now, mi, day));
      }
    }
    final n = numeric.firstMatch(lower);
    if (n != null) {
      final a = int.tryParse(n.group(1)!);
      final b = int.tryParse(n.group(2)!);
      final yearStr = n.group(3);
      if (a != null && b != null && b >= 1 && b <= 12 && in1to31(a)) {
        var year = now.year;
        if (yearStr != null) {
          final y = int.parse(yearStr);
          year = y < 100 ? 2000 + y : y;
        }
        try {
          return dateOnly(DateTime(year, b, a));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Finds a time of day mentioned in [text]: "5pm", "5:30 pm", "17:30",
  /// "noon", "midnight", or a rough guess for "morning"/"afternoon"/
  /// "evening"/"night". Returns null if nothing time-like is found.
  static ParsedTime? extractTime(String text) {
    final lower = text.toLowerCase();

    final ampm =
        RegExp(r'\b(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\b');
    final m = ampm.firstMatch(lower);
    if (m != null) {
      var h = int.parse(m.group(1)!);
      final min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
      final isPm = m.group(3)!.startsWith('p');
      if (h >= 1 && h <= 12 && min <= 59) {
        if (h == 12) h = 0;
        if (isPm) h += 12;
        return ParsedTime(h, min);
      }
    }

    final h24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');
    final m2 = h24.firstMatch(lower);
    if (m2 != null) {
      return ParsedTime(int.parse(m2.group(1)!), int.parse(m2.group(2)!));
    }

    if (lower.contains('noon')) return const ParsedTime(12, 0);
    if (lower.contains('midnight')) return const ParsedTime(0, 0);
    if (RegExp(r'\bmorning\b').hasMatch(lower)) return const ParsedTime(9, 0);
    if (RegExp(r'\bafternoon\b').hasMatch(lower)) return const ParsedTime(15, 0);
    if (RegExp(r'\bevening\b').hasMatch(lower)) return const ParsedTime(18, 0);
    if (RegExp(r'\bnight\b').hasMatch(lower)) return const ParsedTime(21, 0);
    return null;
  }

  static bool in1to31(int d) => d >= 1 && d <= 31;

  /// If the user doesn't pick a deadline, every one-off task still gets one:
  /// today at 6:00 PM, or tomorrow at 6:00 PM if it's already past 6 today
  /// (so a freshly created task doesn't look overdue the instant it's made).
  static DateTime defaultDeadline() {
    final now = DateTime.now();
    final sixToday = DateTime(now.year, now.month, now.day, 18, 0);
    return now.isBefore(sixToday)
        ? sixToday
        : sixToday.add(const Duration(days: 1));
  }

  static DateTime _resolveYear(DateTime now, int month, int day) {
    var year = now.year;
    try {
      var d = DateTime(year, month, day);
      if (d.isBefore(DateTime(now.year, now.month, now.day))) {
        d = DateTime(year + 1, month, day);
      }
      return d;
    } catch (_) {
      return DateTime(year, month, day);
    }
  }
}
