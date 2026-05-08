import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ImpactEvent {
  const ImpactEvent({
    required this.level,
    required this.magnitude,
    required this.detectedAt,
    required this.description,
  });

  final int level;
  final double magnitude;
  final DateTime detectedAt;
  final String description;
}

class ImpactDetectionService {
  ImpactDetectionService({this.onImpact});

  static const double _minimumImpactThreshold = 16.0;
  static const double _minimumShockDelta = 6.0;
  static const String _backgroundPromptedKey = 'impact_background_prompted';
  static const String _backgroundAlertsEnabledKey =
      'impact_background_alerts_enabled';

  final void Function(ImpactEvent event)? onImpact;

  static final Set<ImpactDetectionService> _activeClients =
      <ImpactDetectionService>{};
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static DateTime? _lastTriggerAt;
  static double _lastMagnitude = 9.8;

  bool _started = false;

  void start() {
    if (kIsWeb) {
      return;
    }
    if (_started) {
      return;
    }
    _started = true;
    _activeClients.add(this);
    _subscription ??= accelerometerEventStream().listen(_onEvent);
  }

  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    _activeClients.remove(this);
    if (_activeClients.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  static Future<void> maybeRequestBackgroundPermission(
    BuildContext context,
  ) async {
    if (kIsWeb) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final backgroundEnabled =
        preferences.getBool(_backgroundAlertsEnabledKey) ?? false;
    if (backgroundEnabled) {
      return;
    }

    final alreadyPrompted =
        preferences.getBool(_backgroundPromptedKey) ?? false;
    if (alreadyPrompted && backgroundEnabled) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final allow = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Allow impact alerts?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'EVSmart+ can keep watching for bump detection alerts and show notification-style warnings when you are not actively using the app.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    if (allow == true) {
      await NotificationService.requestSystemPermissions();
      await preferences.setBool(_backgroundPromptedKey, true);
      await preferences.setBool(_backgroundAlertsEnabledKey, true);
    } else {
      await preferences.setBool(_backgroundPromptedKey, false);
      await preferences.setBool(_backgroundAlertsEnabledKey, false);
    }
  }

  static Future<bool> backgroundAlertsEnabled() async {
    if (kIsWeb) {
      return false;
    }
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_backgroundAlertsEnabledKey) ?? false;
  }

  static Future<void> setBackgroundAlertsEnabled(
    bool enabled, {
    bool markPrompted = true,
  }) async {
    if (kIsWeb) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_backgroundAlertsEnabledKey, enabled);
    await preferences.setBool(_backgroundPromptedKey, markPrompted && enabled);
  }

  static void _onEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final shockDelta = (magnitude - _lastMagnitude).abs();
    _lastMagnitude = magnitude;

    if (magnitude < _minimumImpactThreshold ||
        shockDelta < _minimumShockDelta) {
      return;
    }

    final now = DateTime.now();
    if (_lastTriggerAt != null &&
        now.difference(_lastTriggerAt!).inSeconds < 8) {
      return;
    }

    final level = _classifyImpactLevel(magnitude);
    if (level == 0) {
      return;
    }

    _lastTriggerAt = now;
    final impact = ImpactEvent(
      level: level,
      magnitude: magnitude,
      detectedAt: now,
      description: _exampleTrigger(level),
    );

    var delivered = false;
    for (final client in _activeClients.toList(growable: false)) {
      final callback = client.onImpact;
      if (callback == null) {
        continue;
      }
      delivered = true;
      callback(impact);
    }

    if (!delivered) {
      unawaited(_showSoftNotificationIfEnabled(impact));
    }
  }

  static Future<void> _showSoftNotificationIfEnabled(ImpactEvent event) async {
    if (!await backgroundAlertsEnabled()) {
      return;
    }

    await NotificationService.showImpactDetectedNotification(
      level: event.level,
      magnitude: event.magnitude,
      body: event.level >= 4
          ? event.description
          : 'A bump or light impact was detected. Open EVSmart+ to review it.',
    );
  }

  static int _classifyImpactLevel(double magnitude) {
    if (magnitude >= 13 && magnitude < 40) {
      return 1;
    }
    if (magnitude >= 41 && magnitude < 70) {
      return 2;
    }
    if (magnitude >= 71 && magnitude < 90) {
      return 3;
    }
    if (magnitude >= 91 && magnitude < 100) {
      return 4;
    }
    if (magnitude >= 101) {
      return 5;
    }
    return 0;
  }

  static String _exampleTrigger(int level) {
    switch (level) {
      case 1:
        return 'Minor vibration or bump detected.';
      case 2:
        return 'Light impact detected.';
      case 3:
        return 'Moderate impact detected.';
      case 4:
        return 'Serious accident pattern detected.';
      case 5:
        return 'Critical collision pattern detected.';
      default:
        return 'Impact sensor trigger detected.';
    }
  }
}
