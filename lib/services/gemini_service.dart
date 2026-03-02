import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - GANTI dengan milikmu (jangan hardcode di production!)
  static const String apiKey = 'AIzaSyDYZV01UaqVT1_eifcuH718AulBoZjy5ls';

  // Gunakan model terbaru sesuai kebutuhan (example: gemini-3-flash-preview)
  static const String model = 'gemini-3-flash-preview';

  // Endpoint resmi Gemini generateContent
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  static Future<String> generateSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      final prompt = _buildPrompt(tasks);
      final url = Uri.parse('$baseUrl?key=$apiKey');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        }
        return 'Tidak ada jadwal yang dihasilkan dari AI.';
      }

      print('API Error - Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 429) {
        throw Exception('Rate limit tercapai (429). Tunggu beberapa menit atau upgrade quota.');
      }
      if (response.statusCode == 401) {
        throw Exception('API key tidak valid (401). Periksa key Anda.');
      }
      if (response.statusCode == 400) {
        throw Exception('Request salah format (400): ${response.body}');
      }
      throw Exception('Gagal memanggil Gemini API (Code: ${response.statusCode})');
    } catch (e) {
      print('Exception saat generate schedule: $e');
      throw Exception('Error saat generate jadwal: $e');
    }
  }

  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    final taskList = tasks
        .map((task) =>
            '- ${task['name']}: ${task['duration']} minutes, Priority: ${task['priority']}')
        .join('\n');

    return '''
You are an AI schedule optimizer. Based on the following tasks, create an optimal daily schedule.

Tasks:
$taskList

Please generate a markdown-formatted schedule that:
1. Orders tasks by priority (High first, then Medium, then Low)
2. Suggests realistic time slots (e.g., 9:00 AM - 10:30 AM)
3. Includes breaks between tasks
4. Starts from 8:00 AM and ends by 6:00 PM
5. Considers task duration

Format the output as a clean Markdown schedule with headings and bullet points.
''';
  }
}
