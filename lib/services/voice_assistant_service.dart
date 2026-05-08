import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantService {
  VoiceAssistantService._();

  static const MethodChannel _platform = MethodChannel('voice_channel');
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsConfigured = false;

  static Future<bool> isSpeechAvailable() async {
    try {
      final result = await _platform.invokeMethod<dynamic>('startVoice');
      return result != null;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> listenForSingleCommand({
    String? prompt,
    Duration listenFor = const Duration(seconds: 6),
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    try {
      await stopSpeaking();
      if (prompt != null && prompt.trim().isNotEmpty) {
        await speak(prompt);
      }
      final result = await _platform.invokeMethod<dynamic>('startVoice');
      final text = result?.toString().trim() ?? '';
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    try {
      if (!_ttsConfigured) {
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(0.48);
        await _tts.awaitSpeakCompletion(true);
        _ttsConfigured = true;
      }

      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
