import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

/// Custom HTTP client that injects the Google access token for calendar calls.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;

  _GoogleAuthClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class CalendarService {
  final gsi.GoogleSignIn _googleSignIn = gsi.GoogleSignIn.instance;
  static bool _isInitialized = false;

  static const List<String> _calendarScopes = [calendar.CalendarApi.calendarScope];

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  /// Insert each task as an event on the user's primary calendar.
  Future<void> addTasksToCalendar(List<Map<String, dynamic>> tasks) async {
    if (tasks.isEmpty) {
      throw Exception('Tidak ada tugas untuk ditambahkan ke Google Calendar.');
    }

    await _ensureInitialized();

    final gsi.GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on gsi.GoogleSignInException catch (e) {
      if (e.code == gsi.GoogleSignInExceptionCode.canceled) {
        throw Exception('Google Sign-In dibatalkan.');
      }
      rethrow;
    }

    final auth = await account.authorizationClient.authorizeScopes(_calendarScopes);
    final token = auth.accessToken;

    final client = _GoogleAuthClient(
      http.Client(),
      {'Authorization': 'Bearer $token'},
    );

    final calendarApi = calendar.CalendarApi(client);

    final sortedTasks = List<Map<String, dynamic>>.from(tasks)
      ..sort((a, b) => _priorityOrder(a['priority']).compareTo(_priorityOrder(b['priority'])));

    var slot = _nextMorningSlot();
    for (final task in sortedTasks) {
      final duration = Duration(minutes: task['duration'] as int);
      final event = calendar.Event(
        summary: '${task['name']} • Prioritas ${task['priority']}',
        description:
            'Durasi ${task['duration']} menit · Dibuat oleh AI Schedule Generator',
        start: calendar.EventDateTime(
          dateTime: slot,
          timeZone: slot.timeZoneName,
        ),
        end: calendar.EventDateTime(
          dateTime: slot.add(duration),
          timeZone: slot.timeZoneName,
        ),
      );

      await calendarApi.events.insert(event, 'primary');
      slot = slot.add(duration + const Duration(minutes: 10));
    }

    client.close();
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
