import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_repository.dart';
import '../services/assist_directory.dart';
import '../services/gemini_service.dart';
import '../services/voice_assistant_service.dart';
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
  static const Map<String, String> _recommendedAmbulanceDriver = {
    'id': 'ambulance_zarul',
    'name': 'Zarul',
    'role': 'Nearby ambulance driver',
    'phone': '+60123456789',
    'vehicle': 'Unit AMB-204',
    'eta': '6 mins',
  };

  static Future<void> startVoice(
    BuildContext context,
    Function(String) onResult,
    Function() onStop,
    Function() onStart,
  ) async {
    try {
      onStart();
      final result = await VoiceAssistantService.listenForSingleCommand();
      onStop();

      if (!context.mounted) {
        return;
      }
      if (result != null && result.toString().isNotEmpty) {
        onResult(result.toString());
        return;
      }
    } catch (_) {
      onStop();
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Voice not available')));
  }

  static Future<void> handleSearch(BuildContext context, String key) async {
    key = key.toLowerCase().trim();

    if (_handleFunKeywords(context, key)) {
      return;
    }

    if (_matchesAny(key, [
      'call ambulance',
      'find ambulance',
      'nearby ambulance',
      'ambulance driver',
      'send ambulance',
      'need ambulance',
      'contact ambulance',
    ])) {
      await _showNearbyAmbulanceLookup(context);
      return;
    }

    if (key.contains('help') ||
        key.contains('assist') ||
        key.contains('emergency') ||
        key.contains('accident') ||
        key.contains('need assistance') ||
        key.contains('i need help')) {
      await _showNearbyAmbulanceLookup(context);
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

    final aiIntent = await GeminiService.voiceCommandIntent(key);
    if (!context.mounted) {
      return;
    }
    if (aiIntent != null && _handleAiIntent(context, aiIntent)) {
      return;
    }

    final aiReply = await GeminiService.voiceSearchReply(key);
    if (!context.mounted) {
      return;
    }

    final spokenReply = aiReply ?? 'Command not recognized';
    unawaited(VoiceAssistantService.speak(spokenReply));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(spokenReply),
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
      unawaited(VoiceAssistantService.speak(reply));
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
        unawaited(_showNearbyAmbulanceLookup(context));
        return true;
      default:
        return false;
    }
  }

  static bool _handleFunKeywords(BuildContext context, String key) {
    if (key.contains('bangla') ||
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

  static Future<void> _showNearbyAmbulanceLookup(BuildContext context) async {
    final nearestHospital = await _nearestHospitalName();
    if (!context.mounted) {
      return;
    }

    Timer? progressTimer;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        double progress = 0;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            progressTimer ??= Timer.periodic(const Duration(milliseconds: 85), (
              timer,
            ) {
              progress = (progress + 0.04).clamp(0.0, 1.0);
              if (dialogContext.mounted) {
                setState(() {});
              }
              if (progress >= 1) {
                timer.cancel();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Searching Nearby Ambulance',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Checking registered ambulance drivers near your location.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nearest hospital route: $nearestHospital',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () {
                      progressTimer?.cancel();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    progressTimer?.cancel();

    if (!context.mounted) {
      return;
    }
    await _showAmbulanceFoundPopup(context, nearestHospital: nearestHospital);
  }

  static Future<void> _showAmbulanceFoundPopup(
    BuildContext context, {
    required String nearestHospital,
  }) async {
    final driverName = _recommendedAmbulanceDriver['name'] ?? 'Zarul';
    final phone = _recommendedAmbulanceDriver['phone'] ?? '';
    final role =
        _recommendedAmbulanceDriver['role'] ?? 'Nearby ambulance driver';
    final eta = _recommendedAmbulanceDriver['eta'] ?? '6 mins';
    final vehicle = _recommendedAmbulanceDriver['vehicle'] ?? 'Unit AMB-204';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: const Text('Ambulance Driver Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driverName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('$role • $vehicle'),
            const SizedBox(height: 10),
            Text('ETA: $eta'),
            Text('Hospital route: $nearestHospital'),
            Text('Contact: $phone'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _openAmbulanceConversation(
                        context,
                        driverName: driverName,
                        phone: phone,
                        nearestHospital: nearestHospital,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Message'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _launchPhoneCall(phone);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Call'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openAmbulanceConversation(
    BuildContext context, {
    required String driverName,
    required String phone,
    required String nearestHospital,
  }) async {
    final locationName = await _currentLocationLabel();
    final threadId = await AppRepository.startAssistanceConversation(
      responderRole: 'hospital',
      responderId: _recommendedAmbulanceDriver['id'],
      responderName: '$driverName Ambulance',
      responderPhone: phone,
      locationName: locationName,
      issueLabel: 'Nearby ambulance support',
      initialMessage:
          'Need ambulance support near $locationName. Recommended nearby driver: $driverName. Hospital route: $nearestHospital.',
      autoDispatch: true,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserMessagePage(initialThreadId: threadId),
      ),
    );
  }

  static Future<String> _nearestHospitalName() async {
    double latitude = 3.1390;
    double longitude = 101.6869;
    try {
      final position = await Geolocator.getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (_) {}

    final nearestHospital = AssistDirectory.nearestProvider(
      AssistDirectory.healthProviders,
      latitude: latitude,
      longitude: longitude,
    );
    return nearestHospital?['name']?.toString() ?? 'Nearest hospital dispatch';
  }

  static Future<String> _currentLocationLabel() async {
    double latitude = 3.1390;
    double longitude = 101.6869;
    try {
      final position = await Geolocator.getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (_) {}

    final locationName = AppRepository.inferLocationName(latitude, longitude);
    final roadName = AppRepository.inferRoadName(latitude, longitude);
    return '$locationName - $roadName';
  }

  static Future<void> _launchPhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
