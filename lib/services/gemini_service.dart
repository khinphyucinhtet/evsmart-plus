import 'gemini_ai_service.dart';

class GeminiService {
  static Future<String> askGemini(String userInput) async {
    final reply = await GeminiAiService.assistantReply(userInput);
    return reply ?? 'Sorry, AI service is not available right now.';
  }

  static Future<String?> askSupportGemini({
    required String responderRole,
    required String responderName,
    required String locationName,
    required String driverMessage,
    required bool imageShared,
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
  }) {
    return GeminiAiService.supportReply(
      responderRole: responderRole,
      responderName: responderName,
      locationName: locationName,
      driverMessage: driverMessage,
      imageShared: imageShared,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );
  }

  static Future<String?> voiceSearchReply(String command) {
    return GeminiAiService.voiceSearchReply(command);
  }

  static Future<Map<String, String>?> voiceCommandIntent(String command) {
    return GeminiAiService.voiceCommandIntent(command);
  }

  static Future<Map<String, String>?> detectEmergencyIntent(
    String command, {
    required int impactLevel,
  }) {
    return GeminiAiService.emergencyVoiceIntent(
      command,
      impactLevel: impactLevel,
    );
  }
}
