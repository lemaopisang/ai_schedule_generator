import 'schedule_parser.dart';

class CalendarService {
  /// Build one Google Calendar link from all tasks as a summary event.
  String buildTaskSummaryLink(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      throw Exception('Tidak ada tugas untuk dibuatkan link Google Calendar.');
    }

    final sortedTasks = List<Map<String, dynamic>>.from(tasks)
      ..sort(
        (a, b) => _priorityOrder(
          a['priority'],
        ).compareTo(_priorityOrder(b['priority'])),
      );

    var slot = _nextMorningSlot();
    DateTime? firstStart;
    DateTime? lastEnd;
    final detailLines = <String>[];

    for (final task in sortedTasks) {
      final duration = Duration(minutes: task['duration'] as int);
      final end = slot.add(duration);
      firstStart ??= slot;
      lastEnd = end;

      detailLines.add(
        '${_displayTime(slot)} - ${_displayTime(end)} | ${task['name']} (${task['duration']} menit, ${task['priority']})',
      );

      slot = slot.add(duration + const Duration(minutes: 10));
    }

    return _buildGoogleCalendarUrl(
      title: 'AI Schedule Summary',
      details:
          'Ringkasan tugas dari AI Schedule Generator\n\n${detailLines.join('\n')}',
      start: firstStart!,
      end: lastEnd!,
    );
  }

  /// Build one Google Calendar link from parsed schedule events.
  String buildParsedEventsSummaryLink(
    List<ScheduleCalendarEvent> events,
  ) {
    if (events.isEmpty) {
      throw Exception('Tidak ada event yang bisa dibuatkan link Google Calendar.');
    }

    final sorted = List<ScheduleCalendarEvent>.from(events)
      ..sort((a, b) => a.start.compareTo(b.start));

    final detailLines = sorted
        .map(
          (item) =>
              '${_displayTime(item.start)} - ${_displayTime(item.end)} | ${item.title}',
        )
        .toList();

    return _buildGoogleCalendarUrl(
      title: 'AI Schedule Summary',
      details:
          'Ringkasan jadwal hasil AI Schedule Generator\n\n${detailLines.join('\n')}',
      start: sorted.first.start,
      end: sorted.last.end,
    );
  }

  String _buildGoogleCalendarUrl({
    required String title,
    required String details,
    required DateTime start,
    required DateTime end,
  }) {
    final params = {
      'action': 'TEMPLATE',
      'text': title,
      'details': details,
      'dates': '${_formatCalendarDate(start)}/${_formatCalendarDate(end)}',
    };

    return Uri.https('calendar.google.com', '/calendar/render', params)
        .toString();
  }

  String _formatCalendarDate(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '$year$month$day' 'T$hour$minute$second' 'Z';
  }

  String _displayTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _priorityOrder(String priority) {
    switch (priority) {
      case 'Tinggi':
        return 0;
      case 'Sedang':
        return 1;
      default:
        return 2;
    }
  }

  DateTime _nextMorningSlot() {
    final now = DateTime.now();
    var slot = DateTime(now.year, now.month, now.day, 8);
    if (slot.isBefore(now)) {
      slot = slot.add(const Duration(days: 1));
    }
    return slot;
  }
}
