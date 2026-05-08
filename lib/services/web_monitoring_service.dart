import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebMonitoringState {
  const WebMonitoringState({
    required this.notificationsEnabled,
    required this.impactDetectionEnabled,
    required this.backgroundSimulationEnabled,
    required this.prompted,
  });

  final bool notificationsEnabled;
  final bool impactDetectionEnabled;
  final bool backgroundSimulationEnabled;
  final bool prompted;

  bool get anyEnabled =>
      notificationsEnabled ||
      impactDetectionEnabled ||
      backgroundSimulationEnabled;

  WebMonitoringState copyWith({
    bool? notificationsEnabled,
    bool? impactDetectionEnabled,
    bool? backgroundSimulationEnabled,
    bool? prompted,
  }) {
    return WebMonitoringState(
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      impactDetectionEnabled:
          impactDetectionEnabled ?? this.impactDetectionEnabled,
      backgroundSimulationEnabled:
          backgroundSimulationEnabled ?? this.backgroundSimulationEnabled,
      prompted: prompted ?? this.prompted,
    );
  }

  static const empty = WebMonitoringState(
    notificationsEnabled: false,
    impactDetectionEnabled: false,
    backgroundSimulationEnabled: false,
    prompted: false,
  );
}

class WebMonitoringService {
  WebMonitoringService._();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _webPromptedKey = 'web_monitoring_prompted';
  static const String _webImpactEnabledKey = 'web_impact_detection_enabled';
  static const String _webBackgroundEnabledKey =
      'web_background_monitoring_enabled';

  static final ValueNotifier<WebMonitoringState> state =
      ValueNotifier<WebMonitoringState>(WebMonitoringState.empty);

  static Future<void> load() async {
    if (!kIsWeb) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final notificationsEnabled =
        preferences.getBool(_notificationsEnabledKey) ?? false;
    final impactEnabled =
        preferences.getBool(_webImpactEnabledKey) ?? false;
    final backgroundEnabled =
        preferences.getBool(_webBackgroundEnabledKey) ?? false;
    final prompted = preferences.getBool(_webPromptedKey) ?? false;

    state.value = WebMonitoringState(
      notificationsEnabled: notificationsEnabled,
      impactDetectionEnabled: impactEnabled,
      backgroundSimulationEnabled: backgroundEnabled,
      prompted: prompted,
    );
  }

  static Future<void> maybePromptAtStartup(BuildContext context) async {
    if (!kIsWeb) {
      return;
    }

    await load();
    if (state.value.prompted || !context.mounted) {
      return;
    }

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Allow web monitoring features?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'EVSmart+ web can simulate impact detection, notification-style alerts, and browser-limited background monitoring while this tab stays active.',
            style: TextStyle(height: 1.45),
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
      await setNotificationsEnabled(true);
      await setImpactDetectionEnabled(true);
      await setBackgroundSimulationEnabled(true);
      await _setPrompted(true);
    } else {
      await _setPrompted(true);
      await load();
    }
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsEnabledKey, enabled);
    state.value = state.value.copyWith(notificationsEnabled: enabled);
  }

  static Future<void> setImpactDetectionEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_webImpactEnabledKey, enabled);
    state.value = state.value.copyWith(impactDetectionEnabled: enabled);
  }

  static Future<void> setBackgroundSimulationEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_webBackgroundEnabledKey, enabled);
    state.value = state.value.copyWith(backgroundSimulationEnabled: enabled);
  }

  static Future<void> turnEverythingOff() async {
    await Future.wait([
      setNotificationsEnabled(false),
      setImpactDetectionEnabled(false),
      setBackgroundSimulationEnabled(false),
    ]);
  }

  static Future<void> _setPrompted(bool prompted) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_webPromptedKey, prompted);
    state.value = state.value.copyWith(prompted: prompted);
  }

  static String bannerMessage(WebMonitoringState current) {
    if (!current.anyEnabled) {
      return 'Web monitoring simulation is off.';
    }
    if (current.backgroundSimulationEnabled && current.impactDetectionEnabled) {
      return 'Web monitoring simulation is active. Browser sensing stays available while this tab remains open.';
    }
    if (current.impactDetectionEnabled) {
      return 'Impact detection simulation is active for the current tab.';
    }
    if (current.notificationsEnabled) {
      return 'Notifications are enabled for EVSmart+ web updates.';
    }
    return 'Web monitoring simulation is available.';
  }
}
