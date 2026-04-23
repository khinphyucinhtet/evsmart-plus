import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_repository.dart';
import '../services/gemini_ai_service.dart';
import 'alert.dart';
import 'change_password.dart';
import 'charge.dart';
import 'edit_profile.dart';
import 'home_driver.dart';
import 'language.dart';
import 'login_page.dart';
import 'nearby_assist_map.dart';
import 'noti.dart';
import 'privacy_policy.dart';
import 'report_problem.dart';
import 'rewards.dart';
import 'support.dart';
import 'terms.dart';
import 'user_message.dart';
import 'view_profile.dart';

class GlobalSearchHandler {
  static const MethodChannel platform = MethodChannel('voice_channel');

  static Future<void> startVoice(
    BuildContext context,
    Function(String) onResult,
    Function() onStop,
    Function() onStart,
  ) async {
    try {
      onStart();
      final result = await platform.invokeMethod('startVoice');
      onStop();

      if (!context.mounted) {
        return;
      }
      if (result != null && result.toString().isNotEmpty) {
        onResult(result.toString());
      }
    } catch (_) {
      onStop();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice not available')));
    }
  }

  static Future<void> handleSearch(BuildContext context, String key) async {
    key = key.toLowerCase().trim();

    if (_handleFunKeywords(context, key)) {
      return;
    }

    if (key.contains('help') ||
        key.contains('assist') ||
        key.contains('emergency') ||
        key.contains('accident') ||
        key.contains('need assistance') ||
        key.contains('i need help')) {
      _showEmergencyVoiceCountdown(context);
      return;
    }

    if (_matchesAny(key, [
      'message',
      'messages',
      'chat',
      'inbox',
      'conversation',
    ])) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserMessagePage()),
      );
      return;
    }

    if (_matchesAny(key, [
      'charging',
      'charger',
      'charging station',
      'nearby charging',
      'find charger',
      'find me nearby charging station',
      'ev station',
      'station',
    ])) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChargePage()),
      );
      return;
    }

    if (_matchesAny(key, [
      'technician',
      'mechanic',
      'workshop',
      'roadside',
      'tow truck',
      'towing',
      'repair',
      'nearby technician',
      'ev technician',
    ])) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const NearbyAssistMapPage(assistType: AssistType.technician),
        ),
      );
      return;
    }

    if (_matchesAny(key, [
      'hospital',
      'ambulance',
      'clinic',
      'health assist',
      'medical',
      'nearby hospital',
    ])) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const NearbyAssistMapPage(assistType: AssistType.health),
        ),
      );
      return;
    }

    if (key.contains('edit profile')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfilePage()),
      );
      return;
    }

    if (key.contains('view profile') || key.contains('profile')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewProfilePage()),
      );
      return;
    }

    if (key.contains('change password') ||
        key.contains('reset password') ||
        key.contains('password')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
      );
      return;
    }

    if (key.contains('report') ||
        key.contains('help bot') ||
        key.contains('chat bot')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportProblemPage()),
      );
      return;
    }

    if (key.contains('support')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupportPage()),
      );
      return;
    }

    if (key.contains('terms')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsPage()),
      );
      return;
    }

    if (key.contains('language')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LanguagePage()),
      );
      return;
    }

    if (key.contains('privacy')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
      );
      return;
    }

    if (key.contains('logout') || key.contains('log out')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    if (key.contains('home')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverHomePage()),
      );
      return;
    }

    if (key.contains('charge')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChargePage()),
      );
      return;
    }

    if (key.contains('alert')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AlertPage()),
      );
      return;
    }

    if (key.contains('noti')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NotificationPage()),
      );
      return;
    }

    if (key.contains('reward')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RewardsPage()),
      );
      return;
    }

    final aiIntent = await GeminiAiService.voiceCommandIntent(key);
    if (!context.mounted) {
      return;
    }
    if (aiIntent != null && _handleAiIntent(context, aiIntent)) {
      return;
    }

    final aiReply = await GeminiAiService.voiceSearchReply(key);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(aiReply ?? 'Command not recognized'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static bool _matchesAny(String key, List<String> phrases) {
    return phrases.any(key.contains);
  }

  static bool _handleAiIntent(
    BuildContext context,
    Map<String, String> intent,
  ) {
    final action = intent['action']?.toLowerCase().trim() ?? '';
    final reply = intent['reply']?.trim();

    void showReply() {
      if (reply == null || reply.isEmpty) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reply), duration: const Duration(seconds: 3)),
      );
    }

    switch (action) {
      case 'home':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomePage()),
        );
        return true;
      case 'charge':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChargePage()),
        );
        return true;
      case 'alert':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AlertPage()),
        );
        return true;
      case 'noti':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NotificationPage()),
        );
        return true;
      case 'rewards':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RewardsPage()),
        );
        return true;
      case 'messages':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserMessagePage()),
        );
        return true;
      case 'technician':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const NearbyAssistMapPage(assistType: AssistType.technician),
          ),
        );
        return true;
      case 'hospital':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const NearbyAssistMapPage(assistType: AssistType.health),
          ),
        );
        return true;
      case 'support':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportPage()),
        );
        return true;
      case 'profile':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewProfilePage()),
        );
        return true;
      case 'edit_profile':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfilePage()),
        );
        return true;
      case 'password':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        );
        return true;
      case 'report':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportProblemPage()),
        );
        return true;
      case 'language':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LanguagePage()),
        );
        return true;
      case 'privacy':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
        );
        return true;
      case 'terms':
        showReply();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TermsPage()),
        );
        return true;
      case 'logout':
        showReply();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return true;
      case 'emergency_help':
        showReply();
        _showEmergencyVoiceCountdown(context);
        return true;
      default:
        return false;
    }
  }

  static bool _handleFunKeywords(BuildContext context, String key) {
    if (key.contains('zarul') ||
        key.contains('zarulll') ||
        key.contains('bangla') ||
        key.contains('bangladeshii') ||
        key.contains('sorrow')) {
      _showSimplePopup(context, 'STUPID', 'Zarul The Bangladeshii');
      return true;
    }

    if (key.contains('ryan') || key.contains('ryan danish')) {
      _showSimplePopup(context, 'STUPID', 'Ryan Bodoh');
      return true;
    }

    if (key.contains('laku') ||
        key.contains('indian') ||
        key.contains('lakulesh')) {
      _showSimplePopup(context, 'STUPID', 'Laku the Indian');
      return true;
    }

    if (key.contains('arab') ||
        key.contains('shihab') ||
        key.contains('arab bombastic')) {
      _showSimplePopup(
        context,
        'ARAB',
        'YOU JUST GOT BOMBED !! \n ARAB BOMBASTICCC SIDE EYE',
        gifUrl:
            'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExYmN4YnJseHlydnMzaHcweHdlaGw0Y2MydjY4aTZhNW1jNjhrYXVpNiZlcD12MV9naWZzX3NlYXJjaCZjdD1n/LlyEb37tEgNYcGpKPg/giphy.gif',
      );
      return true;
    }

    return false;
  }

  static void _showSimplePopup(
    BuildContext context,
    String title,
    String message, {
    String? gifUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gifUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Image.network(gifUrl, height: 120, fit: BoxFit.cover),
              ),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showEmergencyVoiceCountdown(BuildContext context) async {
    int seconds = 10;
    bool cancelled = false;
    Timer? timer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (value) async {
              if (seconds == 0) {
                value.cancel();
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                await _sendVoiceEmergencyAlert(context);
                return;
              }

              seconds -= 1;
              if (dialogContext.mounted) {
                setState(() {});
              }
            });

            return AlertDialog(
              title: const Text(
                'Potential accident detected. Cancel if safe.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Voice emergency command received. Level 5 SOS will be sent unless this was accidental.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Emergency services will be notified in $seconds seconds.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: seconds / 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This uses the same emergency Firebase flow as Level 4/5 impact alerts.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    timer?.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    if (cancelled && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency voice request cancelled.')),
      );
    }
  }

  static Future<void> _sendVoiceEmergencyAlert(BuildContext context) async {
    double latitude = 3.1390;
    double longitude = 101.6869;
    try {
      final position = await Geolocator.getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (_) {}

    final locationName = AppRepository.inferLocationName(latitude, longitude);
    final roadName = AppRepository.inferRoadName(latitude, longitude);

    await AppRepository.sendManualAlert(
      impactLevel: 5,
      vehicleStatus:
          'Voice SOS requested. Driver asked for emergency help through EVSmart+ voice command.',
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: true,
      sourceDetail: 'voice_command',
      title: 'Voice emergency SOS',
      accidentStatus: 'Critical emergency response required',
      extraData: {
        'gps_location':
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        'location': '$locationName - $roadName',
        'impact_detected_by': 'Voice command emergency trigger',
      },
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Level 5 voice SOS sent to hospital dashboard.'),
      ),
    );
  }
}
