import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'app_repository.dart';

const String _notificationsEnabledKey = 'notifications_enabled';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.ensureBackgroundInitialized();
  await NotificationService.showRemoteMessageNotification(message);
}

class NotificationService {
  NotificationService._();

  static const AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
        'evsmart_emergency_alerts',
        'EVSmart Emergency Alerts',
        description:
            'High-priority EVSmart alerts for hospitals and ambulance drivers.',
        importance: Importance.max,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>? _alertSubscription;
  static final Map<String, String> _alertStateCache = <String, String>{};
  static bool _initialized = false;

  static bool get _supportsDeviceNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> initialize() async {
    if (_supportsDeviceNotifications) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    await ensureInitialized();
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    if (_supportsDeviceNotifications) {
      await _initializeLocalNotifications();
      await requestSystemPermissions();
      FirebaseMessaging.onMessage.listen(showRemoteMessageNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((_) {});
    }

    await _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _handleAuthStateChanged(user);
    });
    await _handleAuthStateChanged(FirebaseAuth.instance.currentUser);
    _initialized = true;
  }

  static Future<void> ensureBackgroundInitialized() async {
    if (_supportsDeviceNotifications) {
      await _initializeLocalNotifications();
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(initializationSettings);

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_emergencyChannel);
  }

  static Future<void> _handleAuthStateChanged(User? user) async {
    await _alertSubscription?.cancel();
    _alertSubscription = null;
    _alertStateCache.clear();

    if (user == null) {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      return;
    }

    await syncMessagingToken();
    if (_supportsDeviceNotifications) {
      _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((token) async {
            final enabled = await areNotificationsEnabled();
            await AppRepository.upsertNotificationToken(
              user.uid,
              token,
              notificationsEnabled: enabled,
            );
          });
    }

    _alertSubscription = AppRepository.streamAlerts().listen((alerts) async {
      await _handleAlertSnapshot(user.uid, alerts);
    });
  }

  static Future<void> syncMessagingToken() async {
    if (!_supportsDeviceNotifications) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    final enabled = await areNotificationsEnabled();
    await AppRepository.upsertNotificationToken(
      user.uid,
      token,
      notificationsEnabled: enabled,
    );
  }

  static Future<bool> areNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsEnabledKey, enabled);

    if (!_supportsDeviceNotifications) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await AppRepository.upsertNotificationToken(
          user.uid,
          token,
          notificationsEnabled: enabled,
        );
      }
    }

    if (!enabled) {
      await _localNotifications.cancelAll();
    }
  }

  static Future<void> requestSystemPermissions() async {
    if (!_supportsDeviceNotifications) {
      return;
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
  }

  static Future<void> _handleAlertSnapshot(
    String uid,
    List<Map<String, dynamic>> alerts,
  ) async {
    if (!_supportsDeviceNotifications || !await areNotificationsEnabled()) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      return;
    }

    final profile = await AppRepository.getCurrentUserProfile() ?? {};
    final role = profile['role']?.toString().toLowerCase() ?? 'driver';
    Map<String, dynamic>? ambulanceProfile;
    if (role.contains('ambulance') || role.contains('hospital')) {
      ambulanceProfile = await AppRepository.getProfileByPath(
        AppRepository.ambulanceProfilesRef,
        uid,
      );
    }

    for (final alert in alerts.take(12)) {
      final payload = _notificationPayloadForAlert(
        alert,
        uid: uid,
        role: role,
        ambulanceProfile: ambulanceProfile,
      );
      if (payload == null) {
        continue;
      }

      final alertId = _alertId(alert);
      final state = _alertSignature(alert);
      final previous = _alertStateCache[alertId];
      _alertStateCache[alertId] = state;

      if (previous == null || previous == state) {
        continue;
      }

      await showLocalNotification(
        id: _stableNotificationId(alertId),
        title: payload.$1,
        body: payload.$2,
        payload: alertId,
      );
    }
  }

  static (String, String)? _notificationPayloadForAlert(
    Map<String, dynamic> alert, {
    required String uid,
    required String role,
    Map<String, dynamic>? ambulanceProfile,
  }) {
    final level = ((alert['impact_level'] ?? 1) as num).toInt();
    final location = _locationText(alert);
    final headline = alert['title']?.toString().trim().isNotEmpty == true
        ? alert['title'].toString().trim()
        : AppRepository.severityLabel(level);
    final status = alert['status']?.toString().toLowerCase() ?? '';
    final dispatchStatus =
        alert['driver_dispatch_status']?.toString().toLowerCase() ?? '';

    if (role.contains('ambulance') || role.contains('hospital')) {
      final dispatchRequested = alert['driver_dispatch_requested'] == true;
      final assignedDriverUid = alert['assigned_driver_uid']?.toString() ?? '';
      final isNearby = _isAlertNearbyToAmbulance(alert, ambulanceProfile);
      final relevantToDriver =
          assignedDriverUid == uid ||
          (dispatchRequested && level >= 4 && isNearby);
      final relevantToHospital = role.contains('hospital') && level >= 4;
      if (!(relevantToDriver || relevantToHospital)) {
        return null;
      }

      if (dispatchStatus == 'report_submitted' ||
          status.contains('report submitted')) {
        return (
          'Driver Report Submitted',
          '$headline at $location now includes patient details for hospital review.',
        );
      }

      if (dispatchStatus == 'arrived' || status.contains('arrived')) {
        return (
          'Ambulance Arrived',
          'Driver reached $location and can submit the hospital report now.',
        );
      }

      if (dispatchStatus == 'accepted' || status.contains('en route')) {
        return (
          'Ambulance En Route',
          '$headline is now en route to $location.',
        );
      }

      return (
        level >= 5 ? 'Level 5 Emergency Alert' : 'Level 4 Emergency Alert',
        '$headline at $location needs attention.',
      );
    }

    if (alert['user_id']?.toString() == uid) {
      return (
        'EVSmart+ Alert Update',
        '$headline at $location has a new status: ${alert['status'] ?? 'Updated'}.',
      );
    }

    return null;
  }

  static bool _isAlertNearbyToAmbulance(
    Map<String, dynamic> alert,
    Map<String, dynamic>? ambulanceProfile,
  ) {
    final alertLat = (alert['latitude'] as num?)?.toDouble();
    final alertLng = (alert['longitude'] as num?)?.toDouble();
    final driverLat = (ambulanceProfile?['current_latitude'] as num?)
        ?.toDouble();
    final driverLng = (ambulanceProfile?['current_longitude'] as num?)
        ?.toDouble();

    if (alertLat == null ||
        alertLng == null ||
        driverLat == null ||
        driverLng == null) {
      return true;
    }

    return _distanceKm(alertLat, alertLng, driverLat, driverLng) <= 10;
  }

  static double _distanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(startLat)) *
            math.cos(_degToRad(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double degrees) => degrees * (math.pi / 180.0);

  static Future<void> showRemoteMessageNotification(
    RemoteMessage message,
  ) async {
    if (!_supportsDeviceNotifications || !await areNotificationsEnabled()) {
      return;
    }

    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'EVSmart+ Alert';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'A new emergency update is available.';

    await showLocalNotification(
      id: _stableNotificationId(
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      title: title,
      body: body,
      payload: message.data['alert_id']?.toString(),
    );
  }

  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_supportsDeviceNotifications) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'evsmart_emergency_alerts',
      'EVSmart Emergency Alerts',
      channelDescription:
          'High-priority EVSmart alerts for hospitals and ambulance drivers.',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_launcher',
      ticker: 'EVSmart Alert',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> showImpactDetectedNotification({
    required int level,
    required double magnitude,
    required String body,
  }) async {
    final label = AppRepository.severityLabel(level);
    await showLocalNotification(
      id: _stableNotificationId(
        'impact_${level}_${DateTime.now().millisecondsSinceEpoch}',
      ),
      title: '$label detected',
      body: '$body (${magnitude.toStringAsFixed(1)} m/s^2)',
      payload: 'impact_level_$level',
    );
  }

  static int _stableNotificationId(String input) {
    return input.hashCode & 0x7fffffff;
  }

  static String _alertId(Map<String, dynamic> alert) {
    return alert['alert_id']?.toString() ?? alert['id']?.toString() ?? '';
  }

  static String _alertSignature(Map<String, dynamic> alert) {
    return [
      alert['status'],
      alert['driver_dispatch_status'],
      alert['assigned_driver_uid'],
      alert['assigned_driver_name'],
      alert['arrival_timestamp'],
      alert['report_submitted_at'],
    ].join('|');
  }

  static String _locationText(Map<String, dynamic> alert) {
    final locationName = alert['location_name']?.toString().trim() ?? '';
    final roadName = alert['road_name']?.toString().trim() ?? '';
    if (locationName.isEmpty && roadName.isEmpty) {
      return 'Unknown location';
    }
    if (locationName.isEmpty) {
      return roadName;
    }
    if (roadName.isEmpty) {
      return locationName;
    }
    return '$locationName - $roadName';
  }
}
