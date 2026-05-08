import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiAiService {
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envDefaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
  static const String _voiceModel = String.fromEnvironment(
    'GEMINI_VOICE_MODEL',
    defaultValue: _envDefaultModel,
  );
  static const String _chatModel = String.fromEnvironment(
    'GEMINI_CHAT_MODEL',
    defaultValue: _envDefaultModel,
  );

  static bool get isConfigured => _envApiKey.trim().isNotEmpty;

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
        ? 'You are a hospital emergency triage assistant for an EV accident app. Sound calm, human, and medically focused. Guide the user like a real emergency desk operator.'
        : 'You are an EV roadside technician workshop assistant. Sound like a real workshop coordinator. Be calm, practical, and helpful for EV breakdown and crash support.';

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
- Reply in 1 to 3 short sentences.
- Usually keep it between 18 and 55 words.
- Sound realistic, not robotic.
- Never reply with only "Noted", "Alright", "Okay", or one-word answers.
- Do not claim you physically inspected the vehicle.
- If hospital: ask about injuries, people count, trapped passengers, smoke/fire, battery heat, or exact location.
- If technician: give one practical safety step, then ask for the next useful EV detail or request a dashboard/vehicle photo.
- If image shared, acknowledge the image naturally, use visible clues if possible, and ask one useful follow-up.
- If severe emergency signs appear, advise safety first and emergency help.
- Do not give generic filler like "let me know" unless paired with a specific question.
- Use natural support phrases like "stay safe", "stop driving", "send your location", "please stand by", or "help is on the way" when appropriate.
- If the user says the EV will not start, ask for a dashboard warning photo or describe the warning lights.
- Vary the tone naturally: sometimes one concise line, sometimes two short lines if the situation needs more detail.

Good reply style examples:
- "Please stay parked for now. Send me a dashboard warning photo and tell me whether the EV powers on or stays fully dead."
- "I can help with that. First, send a photo of the damaged side or the dashboard if any warning is showing."
- "Please stand by in a safe place. Tell me if anyone is injured and whether there is smoke, heat, or a battery warning."
''';

    return _generateShortText(
      prompt,
      model: _chatModel,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );
  }

  static Future<String?> voiceSearchReply(String command) async {
    final prompt =
        '''
You are EVSmart+ voice assistant for an EV accident-response app.

User command: "$command"

Reply in one short helpful sentence.
If this sounds like navigation, mention the likely app section: Home, Charge, Alert, Noti, Rewards, Profile, Messages, Support, Technician Assist, or Emergency Assist.
If unclear, infer the most likely EVSmart+ feature and suggest one next step.
Keep it under 22 words.
''';

    return _generateShortText(prompt, model: _voiceModel);
  }

  static Future<String?> assistantReply(String userInput) async {
    final prompt =
        '''
You are EVSmart+ AI assistant.

Reply short, calm, and practical.
Help with EV accident, charging, technician, hospital, and emergency support.
Keep it under 2 sentences and under 34 words.
Do not answer with one-word replies.

User: "$userInput"
''';

    return _generateShortText(prompt, model: _chatModel);
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
- For inbox, contact support, send message, route to messages.
- For account details, driver details, personal info, route to profile or edit_profile.
- For settings-style requests, choose the nearest meaningful destination rather than unknown.
- Reply must be short, friendly, under 18 words.
''';

    final raw = await _generateShortText(prompt, model: _voiceModel);
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

  static Future<Map<String, String>?> emergencyVoiceIntent(
    String command, {
    required int impactLevel,
  }) async {
    final prompt =
        '''
You are EVSmart+ emergency voice command understanding.

Severity level: $impactLevel
User said: "$command"

Return only valid compact JSON:
{"action":"...","reply":"..."}

Allowed actions:
send_alert, cancel_alert, call_ambulance, find_technician, find_charging_station, hospital_chat, unknown

Rules:
- Keep reply calm, short, and under 18 words.
- If the user wants emergency help, send_alert or call_ambulance is best.
- If they ask for workshop, mechanic, towing, or repair, use find_technician.
- If they ask for charger, low battery, charging station, or range help, use find_charging_station.
- If they ask to contact hospital or emergency team by message, use hospital_chat.
- If they ask to stop or cancel and the alert is already severe, use cancel_alert.
- If the wording is indirect, infer the safest action.
''';

    final raw = await _generateShortText(prompt, model: _voiceModel);
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
    String? model,
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
  }) async {
    if (!isConfigured) {
      return null;
    }

    final requestedModel = model?.trim() ?? '';
    final resolvedModel = requestedModel.isEmpty
        ? _envDefaultModel
        : requestedModel;
    final apiKey = _envApiKey.trim();

    if (apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$resolvedModel:generateContent',
      {'key': apiKey},
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
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
                'temperature': 0.72,
                'topP': 0.9,
                'maxOutputTokens': 140,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Gemini request failed (${response.statusCode}): ${response.body}',
        );
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
      debugPrint('Gemini request timed out.');
      return null;
    } catch (error) {
      debugPrint('Gemini request exception: $error');
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
