class ScheduleCalendarEvent {
  final String title;
  final DateTime start;
  final DateTime end;

  const ScheduleCalendarEvent({
    required this.title,
    required this.start,
    required this.end,
  });
}

class ScheduleParser {
  static final RegExp _timeRangeRegex = RegExp(
    r'(?i)(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?',
  );

  static List<ScheduleCalendarEvent> parseMarkdownSchedule(
    String markdown,
    DateTime baseDate,
  ) {
    final events = <ScheduleCalendarEvent>[];
    final lines = markdown.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _timeRangeRegex.firstMatch(line);
      if (match == null) continue;

      final startHour = int.tryParse(match.group(1) ?? '');
      final startMinute = int.tryParse(match.group(2) ?? '0');
      final startPeriod = match.group(3);

      final endHour = int.tryParse(match.group(4) ?? '');
      final endMinute = int.tryParse(match.group(5) ?? '0');
      final endPeriod = match.group(6);

      if (startHour == null ||
          endHour == null ||
          startMinute == null ||
          endMinute == null) {
        continue;
      }

      var start = _toDateTime(baseDate, startHour, startMinute, startPeriod);
      var end = _toDateTime(baseDate, endHour, endMinute, endPeriod);

      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }

      final title = _extractTitle(line, match.end);

      events.add(ScheduleCalendarEvent(title: title, start: start, end: end));
    }

    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  static DateTime _toDateTime(
    DateTime baseDate,
    int hour,
    int minute,
    String? period,
  ) {
    var normalizedHour = hour;

    if (period != null && period.isNotEmpty) {
      final upper = period.toUpperCase();
      if (upper == 'AM') {
        normalizedHour = hour % 12;
      } else if (upper == 'PM') {
        normalizedHour = (hour % 12) + 12;
      }
    }

    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      normalizedHour,
      minute,
    );
  }

  static String _extractTitle(String line, int matchEndIndex) {
    var candidate = line.substring(matchEndIndex).trim();

    if (candidate.startsWith('|')) {
      candidate = candidate.substring(1).trim();
    }

    candidate = candidate
        .replaceAll(RegExp(r'^[:\-\s|]+'), '')
        .replaceAll(RegExp(r'[|]+'), ' · ')
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (candidate.isEmpty) {
      return 'AI Schedule Event';
    }

    if (candidate.length > 80) {
      return '${candidate.substring(0, 77)}...';
    }

    return candidate;
  }
}
