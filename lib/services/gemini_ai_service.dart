import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiAiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash-lite',
  );

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static Future<String?> supportReply({
    required String responderRole,
    required String responderName,
    required String locationName,
    required String driverMessage,
    required bool imageShared,
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
  }) async {
    final roleInstruction = responderRole == 'hospital'
        ? 'You are a hospital emergency triage assistant for an EV accident app. Be calm, safety-focused, and ask only the most important next triage question.'
        : 'You are an EV roadside technician workshop assistant. Be practical, concise, and ask for the next useful vehicle detail.';

    final prompt =
        '''
$roleInstruction

Context:
- App: EVSmart+
- Responder: $responderName
- Location: $locationName
- Image shared: ${imageShared ? 'yes' : 'no'}
- Driver says: "$driverMessage"

Rules:
- Reply in 1 to 2 short sentences.
- Keep it under 35 words.
- Sound realistic, not robotic.
- Do not claim you physically inspected the vehicle.
- If hospital: ask about injuries, people count, trapped passengers, smoke/fire, battery heat, or exact location.
- If technician: give one practical safety step, then ask for location or one useful EV detail.
- If image shared, use visible clues from the photo if possible and ask one useful follow-up.
- If severe emergency signs appear, advise safety first and emergency help.
''';

    return _generateShortText(
      prompt,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );
  }

  static Future<String?> voiceSearchReply(String command) async {
    final prompt =
        '''
You are EVSmart+ voice assistant for an EV accident-response app.

User command: "$command"

Reply in one short helpful sentence. If this sounds like navigation, mention the likely app section: Home, Charge, Alert, Noti, Rewards, Profile, Messages, Support, Technician Assist, or Emergency Assist.
If unclear, politely say what the user can try next. Keep it under 25 words.
''';

    return _generateShortText(prompt);
  }

  static Future<Map<String, String>?> voiceCommandIntent(String command) async {
    final prompt =
        '''
You are EVSmart+ voice command understanding.

User said: "$command"

Return only valid compact JSON with:
{"action":"...","reply":"..."}

Allowed actions:
home, charge, alert, noti, rewards, messages, technician, hospital, support, profile, edit_profile, password, report, language, privacy, terms, logout, emergency_help, unknown

Rules:
- Pick the best action from the user's meaning, not exact words.
- For nearby charger, charging point, battery low, route to charge.
- For EV workshop, mechanic, tow, repair, route to technician.
- For ambulance, clinic, injury, hospital, route to hospital.
- For accident, crash, SOS, urgent help, route to emergency_help.
- Reply must be short, friendly, under 18 words.
''';

    final raw = await _generateShortText(prompt);
    if (raw == null) {
      return null;
    }

    try {
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final action = decoded['action']?.toString().trim() ?? '';
      final reply = decoded['reply']?.toString().trim() ?? '';
      if (action.isEmpty) {
        return null;
      }
      return {'action': action, 'reply': reply};
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _generateShortText(
    String prompt, {
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
  }) async {
    if (!isConfigured) {
      return null;
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                    if (imageBase64 != null && imageBase64.trim().isNotEmpty)
                      {
                        'inline_data': {
                          'mime_type': imageMimeType,
                          'data': imageBase64,
                        },
                      },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.55,
                'topP': 0.9,
                'maxOutputTokens': 80,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        return null;
      }

      final content = candidates.first['content'];
      if (content is! Map<String, dynamic>) {
        return null;
      }

      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) {
        return null;
      }

      final text = parts
          .whereType<Map>()
          .map((part) => part['text']?.toString() ?? '')
          .where((text) => text.trim().isNotEmpty)
          .join(' ')
          .trim();

      if (text.isEmpty) {
        return null;
      }

      return _cleanReply(text);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _cleanReply(String text) {
    final compact = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'''^['"]|['"]$'''), '')
        .trim();
    if (compact.length <= 240) {
      return compact;
    }
    return '${compact.substring(0, 237).trim()}...';
  }
}
