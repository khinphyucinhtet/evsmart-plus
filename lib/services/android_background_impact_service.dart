import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'impact_detection_service.dart';

class AndroidBackgroundImpactService {
  AndroidBackgroundImpactService._();

  static const MethodChannel _channel = MethodChannel(
    'evsmart/background_impact',
  );

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start() async {
    if (!_supported || !await ImpactDetectionService.backgroundAlertsEnabled()) {
      return;
    }
    await _channel.invokeMethod<void>('startService');
  }

  static Future<void> stop() async {
    if (!_supported) {
      return;
    }
    await _channel.invokeMethod<void>('stopService');
  }

  static Future<void> updateContext({
    required double latitude,
    required double longitude,
    required String locationName,
    required String roadName,
  }) async {
    if (!_supported) {
      return;
    }

    await _channel.invokeMethod<void>('updateContext', {
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'road_name': roadName,
    });
  }
}
