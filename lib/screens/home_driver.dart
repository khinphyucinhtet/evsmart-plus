import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_repository.dart';
import '../services/assist_directory.dart';
import '../services/android_background_impact_service.dart';
import '../services/impact_detection_service.dart';
import '../services/notification_service.dart';
import 'alert.dart';
import 'app_footer.dart';
import 'app_header.dart';
import 'charge.dart';
import 'global_search.dart';
import 'noti.dart';
import 'rewards.dart';
import 'user_message.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  String weatherTemp = '--';
  String weatherDesc = 'Syncing weather';
  String city = 'Kuala Lumpur';

  double batteryLevel = 0.78;
  String batteryHealth = 'Good';
  int batteryVoltage = 352;
  double batteryCurrent = -18.6;
  double batteryTemperature = 32;
  String chargingStatus = 'Charging Safely';
  String chargingPortStatus = 'Locked and stable';
  String batterySafetyStatus = 'Normal';
  int suddenBrakingEvents = 2;
  int tirePressurePsi = 34;
  int tireTemperature = 28;
  int motorTemperature = 32;
  int cabinTemperature = 25;
  int estimatedRangeKm = 286;
  String driveMode = 'Eco';
  bool isEvConnected = true;
  String selectedEvModel = 'Demo Battery EV';
  String evConnectionMethod = 'EV CAN simulation';
  String vehicleConnectionStatus = 'Connected to EV control module';
  String inverterStatus = 'Healthy';
  DateTime lastSystemCheckAt = DateTime.now();
  DateTime? disconnectedAt;
  String lastEvSnapshot = 'Battery 78%, range 286 km, tire 34 PSI';
  String impactStatus = 'Monitoring active';
  String lastImpactLabel = 'No impact';
  DateTime? lastImpactAt;
  int activeImpactLevel = 0;
  String? activeImpactZone;
  final List<String> _activeImpactZones = <String>[];
  final List<String> _pendingImpactZones = <String>[];
  String impactAutoAlertStatus = 'Standby';
  LatLngState currentLocation = const LatLngState(
    latitude: 3.1390,
    longitude: 101.6869,
  );

  late final ImpactDetectionService _impactService;
  bool _isImpactDialogVisible = false;
  final Random _impactRandom = Random();

  bool get _isWebDemoMode => kIsWeb;

  String get _defaultImpactStatus => 'Monitoring active';

  String get _alertSourceDetail => 'Phone accelerometer IoT simulation';

  @override
  void initState() {
    super.initState();
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    if (!_isWebDemoMode) {
      _impactService.start();
    }
    fetchWeather();
    _loadLocation();
    AppRepository.ensureChargingStations();
  }

  @override
  void dispose() {
    _impactService.stop();
    super.dispose();
  }

  Future<void> fetchWeather() async {
    const url =
        'https://api.openweathermap.org/data/2.5/weather?q=Kuala%20Lumpur&units=metric&appid=c4916f37ca48e68046a893f7b38e43e1';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) {
        return;
      }

      setState(() {
        weatherTemp = '${(data['main']['temp'] as num).round()} C';
        weatherDesc = data['weather'][0]['main'].toString();
        city = data['name'].toString();
      });
    } catch (_) {}
  }

  Future<void> _loadLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) {
        return;
      }
      setState(() {
        currentLocation = LatLngState(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });

      if (!_isWebDemoMode) {
        await AndroidBackgroundImpactService.updateContext(
          latitude: position.latitude,
          longitude: position.longitude,
          locationName: AppRepository.inferLocationName(
            position.latitude,
            position.longitude,
          ),
          roadName: AppRepository.inferRoadName(
            position.latitude,
            position.longitude,
          ),
        );
      }
    } catch (_) {}
  }

  void _handleImpactDetected(ImpactEvent event) {
    if (!mounted || _isImpactDialogVisible) {
      return;
    }

    final levelLabel = AppRepository.severityLabel(event.level);
    setState(() {
      lastImpactLabel = levelLabel;
      lastImpactAt = event.detectedAt;
      impactStatus =
          'Impact detected (${event.magnitude.toStringAsFixed(1)} m/s^2)';
    });

    if (event.level >= 4) {
      _applyImpactSimulation(level: event.level);
    } else {
      _resetImpactSimulation(keepStatus: true);
    }

    _showEmergencyCountdown(
      title: 'Potential accident detected. Cancel if safe.',
      subtitle:
          '$levelLabel detected from the phone accelerometer. ${event.description}',
      impactLevel: event.level,
      source: 'accelerometer',
      autoDispatch: event.level >= 4,
      accelerationMagnitude: event.magnitude,
    );
  }

  void _applyImpactSimulation({required int level, String? preferredZone}) {
    setState(() {
      activeImpactLevel = level;
      _activeImpactZones
        ..clear()
        ..addAll(_randomImpactZones(level, preferredZone: preferredZone));
      activeImpactZone = _activeImpactZones.isEmpty
          ? null
          : _activeImpactZones.first;
      lastImpactAt = DateTime.now();
      lastImpactLabel = AppRepository.severityLabel(level);
      impactStatus = level >= 4
          ? 'Severe impact detected'
          : _defaultImpactStatus;
      impactAutoAlertStatus = level >= 4 ? 'Standby' : 'Standby';
      _pendingImpactZones.clear();
    });
  }

  List<String> _randomImpactZones(int level, {String? preferredZone}) {
    if (preferredZone != null) {
      return <String>[preferredZone];
    }

    final zones = <String>[
      'front_left',
      'front_right',
      'left_side',
      'right_side',
      'rear_left',
      'rear_right',
    ];
    zones.shuffle(_impactRandom);
    final zoneCount = level >= 5 ? 2 : 1;
    return zones.take(zoneCount).toList();
  }

  void _resetImpactSimulation({bool keepStatus = false}) {
    setState(() {
      activeImpactLevel = 0;
      activeImpactZone = null;
      _activeImpactZones.clear();
      _pendingImpactZones.clear();
      impactAutoAlertStatus = isEvConnected ? 'Standby' : 'Inactive';
      if (!keepStatus) {
        impactStatus = _defaultImpactStatus;
        lastImpactLabel = 'No impact';
        lastImpactAt = null;
      }
    });
  }

  Future<void> _createAlert({
    required int impactLevel,
    required String source,
    required bool emergencyTriggered,
    double? accelerationMagnitude,
  }) async {
    await _loadLocation();

    final isManualTrigger = source == 'manual_sos' || source == 'demo_button';
    final alert = isManualTrigger
        ? await AppRepository.sendManualAlert(
            impactLevel: impactLevel,
            vehicleStatus: _vehicleStatusForLevel(impactLevel),
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
            emergencyTriggered: emergencyTriggered,
            sourceDetail: source,
            accelerationMagnitude: accelerationMagnitude,
            extraData: {
              'gps_location':
                  '${currentLocation.latitude.toStringAsFixed(5)}, ${currentLocation.longitude.toStringAsFixed(5)}',
              'impact_detected_by': _alertSourceDetail,
            },
          )
        : await AppRepository.sendAutomaticAlert(
            impactLevel: impactLevel,
            vehicleStatus: _vehicleStatusForLevel(impactLevel),
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
            emergencyTriggered: emergencyTriggered,
            sourceDetail: source,
            accelerationMagnitude: accelerationMagnitude,
            extraData: {
              'gps_location':
                  '${currentLocation.latitude.toStringAsFixed(5)}, ${currentLocation.longitude.toStringAsFixed(5)}',
              'impact_detected_by': _alertSourceDetail,
            },
          );

    if (!mounted) {
      return;
    }

    setState(() {
      impactStatus = emergencyTriggered
          ? 'Emergency dispatch sent'
          : 'Impact logged successfully';
      lastImpactLabel = alert['impact_label'].toString();
      lastImpactAt =
          DateTime.tryParse(alert['timestamp'].toString()) ?? DateTime.now();
      activeImpactLevel = impactLevel >= 4 ? impactLevel : 0;
      if (impactLevel >= 4) {
        if (_activeImpactZones.isEmpty) {
          _activeImpactZones.addAll(_randomImpactZones(impactLevel));
        }
        activeImpactZone = _activeImpactZones.first;
      } else {
        activeImpactZone = null;
        _activeImpactZones.clear();
      }
      impactAutoAlertStatus = emergencyTriggered
          ? 'Sent to Hospital'
          : 'Standby';
    });

    if (!emergencyTriggered && impactLevel <= 3) {
      await NotificationService.showImpactDetectedNotification(
        level: impactLevel,
        magnitude: accelerationMagnitude ?? 0,
        body:
            'A bump or vehicle impact was detected. Open EVSmart+ to review it.',
      );
    }

    await _showHelpOnTheWay(
      emergencyTriggered,
      alert['impact_label'].toString(),
    );
  }

  Future<void> _showEmergencyCountdown({
    required String title,
    required String subtitle,
    required int impactLevel,
    required String source,
    required bool autoDispatch,
    double? accelerationMagnitude,
  }) async {
    if (_isImpactDialogVisible) {
      return;
    }

    _isImpactDialogVisible = true;
    int seconds = 10;
    bool cancelled = false;
    Timer? timer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (value) async {
              if (seconds == 0) {
                value.cancel();
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                await _createAlert(
                  impactLevel: impactLevel,
                  source: source,
                  emergencyTriggered: autoDispatch,
                  accelerationMagnitude: accelerationMagnitude,
                );
                return;
              }

              seconds -= 1;
              if (context.mounted) {
                setState(() {});
              }
            });

            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(subtitle),
                  const SizedBox(height: 16),
                  Text(
                    autoDispatch
                        ? 'Emergency services will be notified in $seconds seconds.'
                        : 'This alert will be saved in $seconds seconds.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: seconds / 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This simulates vehicle IoT impact sensors for the EVSmart+ prototype.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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
    _isImpactDialogVisible = false;
    if (cancelled && mounted) {
      setState(() {
        impactStatus = _defaultImpactStatus;
        lastImpactLabel = 'No impact';
        lastImpactAt = null;
        activeImpactLevel = 0;
        activeImpactZone = null;
        _activeImpactZones.clear();
        _pendingImpactZones.clear();
        impactAutoAlertStatus = isEvConnected ? 'Standby' : 'Inactive';
      });
    }
  }

  Future<void> _showHelpOnTheWay(
    bool emergencyTriggered,
    String severityLabel,
  ) async {
    final nearestHospital = AssistDirectory.nearestProvider(
      AssistDirectory.healthProviders,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
    );

    await showDialog<void>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            emergencyTriggered ? 'Help is on the way' : 'Alert logged',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emergencyTriggered
                    ? '$severityLabel was sent to Firebase, the hospital dashboard, the notification page, and insurance analytics.'
                    : '$severityLabel was stored in Firebase and added to the alert history and notification page.',
              ),
              if (emergencyTriggered && nearestHospital != null) ...[
                const SizedBox(height: 14),
                const Text(
                  'Nearest hospital contact',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(nearestHospital['name']?.toString() ?? 'Hospital'),
                const SizedBox(height: 4),
                Text(nearestHospital['address']?.toString() ?? '-'),
                const SizedBox(height: 4),
                Text(nearestHospital['phone']?.toString() ?? '-'),
              ],
            ],
          ),
          actions: [
            if (emergencyTriggered && nearestHospital != null)
              TextButton(
                onPressed: () async {
                  final phone = nearestHospital['phone']?.toString() ?? '';
                  if (phone.isNotEmpty) {
                    await launchUrl(Uri(scheme: 'tel', path: phone));
                  }
                },
                child: const Text(
                  'Call nearest hospital',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (emergencyTriggered && nearestHospital != null)
              TextButton(
                onPressed: () async {
                  final threadId = await AppRepository.startAssistanceConversation(
                    responderRole: 'hospital',
                    responderId: nearestHospital['id']?.toString(),
                    responderName:
                        nearestHospital['name']?.toString() ?? 'Hospital',
                    responderPhone: nearestHospital['phone']?.toString() ?? '',
                    locationName:
                        nearestHospital['address']?.toString() ??
                        'Current location',
                    issueLabel: 'Emergency Assist',
                    initialMessage:
                        'Emergency detected near ${nearestHospital['address']}. Please help the EV driver immediately.',
                    autoDispatch: true,
                  );
                  if (!mounted) {
                    return;
                  }
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserMessagePage(initialThreadId: threadId),
                    ),
                  );
                },
                child: const Text(
                  'Message nearest hospital',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
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
  }

  String _vehicleStatusForLevel(int level) {
    switch (level) {
      case 1:
        return 'Small bump detected. Driver should inspect vehicle body and bumper alignment.';
      case 2:
        return 'Minor collision suspected. Brake, tire, and sensor checks recommended.';
      case 3:
        return 'Moderate accident detected. Vehicle diagnostics and technician support required.';
      case 4:
        return 'Severe accident suspected. Emergency support and ambulance dispatch initiated.';
      case 5:
        return 'Critical crash pattern detected. Immediate emergency response required.';
      default:
        return 'Vehicle status unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onSearch: (key) {
                key = key.toLowerCase().trim();
                GlobalSearchHandler.handleSearch(context, key);
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: AppFooter(currentIndex: 0, onTap: _handleFooterTap),
    );
  }

  void _handleFooterTap(int index) {
    if (index == 0) {
      return;
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChargePage()),
      );
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AlertPage()),
      );
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NotificationPage()),
      );
    }

    if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RewardsPage()),
      );
    }
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900
            ? 28.0
            : constraints.maxWidth < 420
            ? 12.0
            : 16.0;
        final contentMaxWidth = constraints.maxWidth >= 1400
            ? 1180.0
            : constraints.maxWidth >= 1100
            ? 1040.0
            : constraints.maxWidth >= 900
            ? 960.0
            : 720.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _carHero(),
                  const SizedBox(height: 18),
                  _connectionSummaryStrip(),
                  const SizedBox(height: 16),
                  _evConnectionCard(),
                  const SizedBox(height: 16),
                  _batteryMonitoringCard(),
                  const SizedBox(height: 16),
                  _vehicleHealthCard(),
                  const SizedBox(height: 16),
                  _impactSensorCard(),
                  const SizedBox(height: 16),
                  _liveSystemStatusPanel(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _evConnectionCard() {
    final linkColor = isEvConnected ? Colors.green : Colors.orange;
    final lastSyncLabel = isEvConnected
        ? 'Live now - ${_formatDate(lastSystemCheckAt)}'
        : 'Last synced ${_formatDate(disconnectedAt ?? lastSystemCheckAt)}';
    final title = 'Connect EV';
    final summary =
        'Connect your EV to sync battery, range, sensor, and charging insights.';
    final featureCards = <Widget>[
      _infoPill(
        Icons.sensors_rounded,
        isEvConnected
            ? 'Sensors linked'
            : 'Sensors disconnected',
        isEvConnected
            ? 'Battery, tire, GPS, impact'
            : 'No live sensor data',
        linkColor,
      ),
      _infoPill(
        Icons.cloud_sync_outlined,
        isEvConnected
            ? 'Cloud connected'
            : 'Cloud paused',
        isEvConnected
            ? 'Firebase sync every 15s'
            : lastSyncLabel,
        linkColor,
      ),
      _infoPill(
        Icons.route_rounded,
        'Estimated range',
        isEvConnected
            ? '$estimatedRangeKm km'
            : '--',
        linkColor,
      ),
      _infoPill(
        Icons.speed_rounded,
        isEvConnected
            ? 'Drive mode'
            : 'Vehicle state',
        isEvConnected
            ? driveMode
            : 'Disconnected',
        linkColor,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Color(0xFF2E7D32),
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount =
                  _isWebDemoMode && constraints.maxWidth < 360 ? 1 : 2;
              final tileHeight = crossAxisCount == 1
                  ? 92.0
                  : constraints.maxWidth < 420
                  ? 116.0
                  : 106.0;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: crossAxisCount == 1
                    ? 3.1
                    : constraints.maxWidth < 420
                    ? 0.98
                    : 1.16,
                children: featureCards
                    .map((child) => SizedBox(height: tileHeight, child: child))
                    .toList(),
              );
            },
          ),
          if (!isEvConnected) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD98C)),
              ),
              child: Text(
                'Disconnected mode: showing cached EV data from the last successful sync. $lastEvSnapshot.',
                style: const TextStyle(
                  color: Color(0xFF7A4B00),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 190,
              child: ElevatedButton.icon(
                onPressed: isEvConnected
                    ? _disconnectEvSimulation
                    : _connectDefaultEvSimulation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEvConnected
                      ? Colors.orange.shade700
                      : const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  isEvConnected
                      ? Icons.link_off_rounded
                      : Icons.ev_station,
                ),
                label: Text(
                  isEvConnected
                      ? 'Disconnect EV'
                      : 'Connect EV',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionSummaryStrip() {
    final accentColor = isEvConnected
        ? const Color(0xFF2E7D32)
        : Colors.orange.shade700;
    final softColor = isEvConnected
        ? const Color(0xFFE9F7EC)
        : const Color(0xFFFFF1DF);
    final statusLabel = isEvConnected ? 'NORMAL' : 'DISCONNECTED';
    final connectivityLabel = isEvConnected ? 'Online' : 'Offline';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: softColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEvConnected ? Icons.check_rounded : Icons.link_off_rounded,
                  color: accentColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Status',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isEvConnected ? 'Live' : 'Disconnected',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _vehicleStatusMeta(
                Icons.access_time_rounded,
                isEvConnected
                    ? 'Last Sync: 15 sec ago'
                    : 'Last Sync: ${_formatDate(disconnectedAt ?? lastSystemCheckAt)}',
              ),
              _vehicleStatusMeta(
                Icons.wifi_tethering_rounded,
                'Connectivity: $connectivityLabel',
                valueColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleStatusMeta(IconData icon, String text, {Color? valueColor}) {
    return IntrinsicWidth(
      child: Row(
        children: [
          Icon(icon, color: valueColor ?? Colors.grey.shade700, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/ic_car_background.png',
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: .62),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Stay safe & drive smart.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    impactStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleHealthCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle Sensors',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _sensorSection(
            title: 'EV Core Systems',
            icon: Icons.bolt_rounded,
            columns: 3,
            keepThreeColumns: true,
            denseTiles: true,
            tileHeightOverride: 106,
            sectionPadding: 8,
            tileSpacing: 5,
            trailing: TextButton(
              onPressed: _showBatteryDetailsDialog,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Details'),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
            items: [
              _sensorItemData(
                icon: Icons.battery_6_bar_rounded,
                title: 'Battery Percent',
                value: isEvConnected
                    ? '${(batteryLevel * 100).round()}%'
                    : '--',
                subtitle: isEvConnected ? batteryHealth : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.device_thermostat_rounded,
                title: 'Motor Temp.',
                value: isEvConnected ? '$motorTemperature°C' : '--',
                subtitle: isEvConnected ? 'Normal' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.memory_rounded,
                title: 'Inverter Status',
                value: isEvConnected ? 'Synced' : '--',
                subtitle: isEvConnected ? 'Normal' : 'Disconnected',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sensorSection(
            title: 'Driving Sensors',
            icon: Icons.directions_car_filled_rounded,
            columns: 3,
            keepThreeColumns: true,
            denseTiles: true,
            tileHeightOverride: 106,
            sectionPadding: 8,
            tileSpacing: 5,
            trailing: TextButton(
              onPressed: _showDrivingDetailsDialog,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Details'),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
            items: [
              _sensorItemData(
                icon: Icons.speed_rounded,
                title: 'Speed',
                value: isEvConnected ? '62 km/h' : '--',
                subtitle: isEvConnected ? 'Normal' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.timeline_rounded,
                title: 'Distance Today',
                value: isEvConnected ? '12.6 km' : '--',
                subtitle: isEvConnected ? 'Normal' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.location_on_rounded,
                title: 'GPS Location',
                value: isEvConnected
                    ? '${currentLocation.latitude.toStringAsFixed(4)}, ${currentLocation.longitude.toStringAsFixed(4)}'
                    : '--',
                subtitle: isEvConnected ? city : 'Disconnected',
                titleMaxLines: 1,
                valueMaxLines: 2,
                smallValue: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sensorSection(
            title: 'Safety Sensors',
            icon: Icons.shield_rounded,
            columns: 3,
            keepThreeColumns: true,
            denseTiles: true,
            tileHeightOverride: 106,
            sectionPadding: 8,
            tileSpacing: 5,
            trailing: TextButton(
              onPressed: _showSafetyDetailsDialog,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Details'),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
            items: [
              _sensorItemData(
                icon: Icons.security_rounded,
                title: 'Impact Sensor',
                value: isEvConnected
                    ? (activeImpactLevel >= 4 ? 'Impact Detected' : 'No Impact')
                    : '--',
                subtitle: isEvConnected
                    ? (activeImpactLevel >= 4
                          ? _impactLocationSummary(_activeImpactZones)
                          : 'Monitoring')
                    : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.warning_amber_rounded,
                title: 'Brake / Sudden Stop',
                value: isEvConnected ? 'Normal' : '--',
                subtitle: isEvConnected
                    ? '$suddenBrakingEvents events'
                    : 'Disconnected',
                titleMaxLines: 2,
              ),
              _sensorItemData(
                icon: Icons.sensor_door_rounded,
                title: 'Door / Collision',
                value: isEvConnected ? 'Closed' : '--',
                subtitle: isEvConnected ? 'All Good' : 'Disconnected',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sensorSection(
            title: 'Tire System',
            icon: Icons.tire_repair_rounded,
            columns: 4,
            trailing: TextButton(
              onPressed: _showTireDetailsDialog,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Details'),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
            items: [
              _sensorItemData(
                icon: Icons.tire_repair_rounded,
                title: 'FL\nTire',
                value: isEvConnected ? '$tirePressurePsi PSI' : '--',
                subtitle: isEvConnected ? 'Good' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.tire_repair_rounded,
                title: 'FR\nTire',
                value: isEvConnected ? '$tirePressurePsi PSI' : '--',
                subtitle: isEvConnected ? 'Good' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.tire_repair_rounded,
                title: 'RL\nTire',
                value: isEvConnected ? '$tirePressurePsi PSI' : '--',
                subtitle: isEvConnected ? 'Good' : 'Disconnected',
              ),
              _sensorItemData(
                icon: Icons.tire_repair_rounded,
                title: 'RR\nTire',
                value: isEvConnected ? '$tirePressurePsi PSI' : '--',
                subtitle: isEvConnected ? 'Good' : 'Disconnected',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sensorSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    int columns = 3,
    Widget? trailing,
    bool keepThreeColumns = false,
    bool denseTiles = false,
    double? tileHeightOverride,
    double sectionPadding = 12,
    double tileSpacing = 8,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int effectiveColumns = columns;
        if (_isWebDemoMode) {
          if (columns == 4) {
            effectiveColumns = width >= 940
                ? 4
                : width >= 520
                ? 2
                : 1;
          } else if (columns == 3) {
            effectiveColumns = width >= 760
                ? 3
                : width >= 420
                ? 2
                : 1;
          }
        } else if (columns == 4 && width < 520) {
          effectiveColumns = 2;
        } else if (columns == 3 && width < 300 && !keepThreeColumns) {
          effectiveColumns = 2;
        }

        final useMicroDense =
            !_isWebDemoMode &&
            keepThreeColumns &&
            denseTiles &&
            columns == 3 &&
            width < 300;
        final useDenseTiles = denseTiles && effectiveColumns >= 3;
        final tileHeight = useMicroDense
            ? 98.0
            : tileHeightOverride ??
                  (useDenseTiles
                      ? 116.0
                      : effectiveColumns >= 3
                      ? 132.0
                      : 122.0);

        return Container(
          padding: EdgeInsets.all(sectionPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE9ECEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  for (final widget in [trailing].whereType<Widget>()) widget,
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: effectiveColumns,
                  crossAxisSpacing: tileSpacing,
                  mainAxisSpacing: tileSpacing,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _sensorTile(
                    item['icon'] as IconData,
                    item['title'] as String,
                    item['value'] as String,
                    item['subtitle'] as String,
                    compact: effectiveColumns >= 3,
                    dense: useDenseTiles,
                    microDense: useMicroDense,
                    titleMaxLines: item['titleMaxLines'] as int? ?? 2,
                    valueMaxLines: item['valueMaxLines'] as int? ?? 1,
                    subtitleMaxLines: item['subtitleMaxLines'] as int? ?? 1,
                    smallValue: item['smallValue'] as bool? ?? false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _sensorItemData({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    int titleMaxLines = 2,
    int valueMaxLines = 1,
    int subtitleMaxLines = 1,
    bool smallValue = false,
  }) {
    return {
      'icon': icon,
      'title': title,
      'value': value,
      'subtitle': subtitle,
      'titleMaxLines': titleMaxLines,
      'valueMaxLines': valueMaxLines,
      'subtitleMaxLines': subtitleMaxLines,
      'smallValue': smallValue,
    };
  }

  Widget _sensorTile(
    IconData icon,
    String title,
    String value,
    String subtitle, {
    bool compact = false,
    bool dense = false,
    bool microDense = false,
    int titleMaxLines = 2,
    int valueMaxLines = 1,
    int subtitleMaxLines = 1,
    bool smallValue = false,
  }) {
    final accentColor = isEvConnected
        ? const Color(0xFF2E7D32)
        : Colors.orange.shade700;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: microDense
            ? 6
            : dense
            ? 7
            : compact
            ? 10
            : 12,
        vertical: microDense
            ? 8
            : dense
            ? 9
            : compact
            ? 14
            : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(
          microDense
              ? 16
              : dense
              ? 18
              : 20,
        ),
        border: Border.all(color: const Color(0xFFE8ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: const Color(0xFF2E7D32),
                size: microDense
                    ? 15
                    : dense
                    ? 17
                    : compact
                    ? 20
                    : 24,
              ),
              SizedBox(
                width: microDense
                    ? 3
                    : dense
                    ? 4
                    : compact
                    ? 5
                    : 8,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: microDense || dense ? titleMaxLines : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: microDense
                        ? 8.2
                        : dense
                        ? 9.1
                        : compact
                        ? 10.4
                        : 11.8,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: microDense
                ? 10
                : dense
                ? 12
                : compact
                ? 12
                : 8,
          ),
          Text(
            value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w900,
              fontSize: microDense
                  ? (smallValue ? 9.8 : 11.4)
                  : dense
                  ? (smallValue ? 11.6 : 13.0)
                  : compact
                  ? 12.8
                  : 14.0,
              height: 1.1,
            ),
          ),
          SizedBox(
            height: microDense
                ? 1
                : dense
                ? 2
                : compact
                ? 1
                : 3,
          ),
          Text(
            subtitle,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: microDense
                  ? 8.4
                  : dense
                  ? 9.3
                  : compact
                  ? 10.6
                  : 11.2,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactSensorCard() {
    final hasSevereImpact =
        isEvConnected &&
        activeImpactLevel >= 4 &&
        _activeImpactZones.isNotEmpty;
    final accentColor = !isEvConnected
        ? Colors.orange.shade700
        : hasSevereImpact
        ? const Color(0xFFE53935)
        : const Color(0xFF2E7D32);
    final softColor = !isEvConnected
        ? const Color(0xFFFFF4E6)
        : hasSevereImpact
        ? const Color(0xFFFFF3F2)
        : const Color(0xFFEAF6EE);
    final impactTitle = !isEvConnected
        ? 'SENSOR OFFLINE'
        : hasSevereImpact
        ? 'IMPACT DETECTED'
        : 'NO IMPACT DETECTED';
    final impactLocation = _impactLocationSummary(_activeImpactZones);
    final impactTime = lastImpactAt == null
        ? '--'
        : 'Today, ${_formatDate(lastImpactAt!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasSevereImpact
                    ? const Color(0xFFF3B1AA)
                    : !isEvConnected
                    ? const Color(0xFFFFD4A3)
                    : const Color(0xFFDCEBDD),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasSevereImpact
                        ? Icons.car_crash_rounded
                        : isEvConnected
                        ? Icons.verified_user_rounded
                        : Icons.sensor_door_outlined,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impact Status',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        impactTitle,
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Color(0xFFEADFDA))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Severity Level',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        !isEvConnected
                            ? '--'
                            : '${hasSevereImpact ? activeImpactLevel : 0} / 5',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7ECE7)),
            ),
            child: Column(
              children: [
                _impactInfoRow(
                  'Impact Location',
                  hasSevereImpact ? impactLocation : '--',
                  valueColor: hasSevereImpact ? Colors.black87 : Colors.black54,
                ),
                _impactInfoRow(
                  'Impact Time',
                  hasSevereImpact ? impactTime : '--',
                  valueColor: Colors.black87,
                ),
                _impactInfoRow(
                  'Monitoring Status',
                  isEvConnected
                      ? 'Active'
                      : 'Inactive',
                  valueColor: isEvConnected
                      ? const Color(0xFF2E7D32)
                      : Colors.orange.shade700,
                ),
                _impactInfoRow(
                  'Auto Alert',
                  impactAutoAlertStatus,
                  valueColor: impactAutoAlertStatus == 'Sent to Hospital'
                      ? const Color(0xFFE53935)
                      : isEvConnected
                      ? const Color(0xFF2E7D32)
                      : Colors.orange.shade700,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _impactZoneLiveCard(hasSevereImpact),
          const SizedBox(height: 18),
          _impactSimulatorCard(),
        ],
      ),
    );
  }

  Widget _impactZoneLiveCard(bool hasSevereImpact) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7ECE7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 520;
          final double carWidth = compact ? 76 : 148;
          final double carHeight = compact ? 198 : 276;
          final double connectorWidth = compact ? 12 : 40;
          final double connectorGap = compact ? 4 : 10;
          final double centerGap = compact ? 8 : 20;
          final double zoneGap = compact ? 10 : 16;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Impact Zone',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: ' (Live View)',
                            style: TextStyle(
                              color: Color(0xFF5F6670),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6EE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: Color(0xFF2E7D32)),
                        SizedBox(width: 6),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: compact ? 7 : 6,
                    child: _impactZoneColumn(
                      <String>['front_left', 'left_side', 'rear_left'],
                      hasSevereImpact,
                      alignRight: false,
                      compact: compact,
                      connectorWidth: connectorWidth,
                      connectorGap: connectorGap,
                      zoneGap: zoneGap,
                    ),
                  ),
                  SizedBox(width: centerGap),
                  SizedBox(
                    width: carWidth,
                    height: carHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/car_imageee.png',
                          width: carWidth,
                          height: carHeight - 10,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: compact ? 10 : 6,
                          child: _impactNode(
                            color: _impactIndicatorColor(<String>[
                              'front_left',
                              'front_right',
                            ], hasSevereImpact),
                          ),
                        ),
                        Positioned(
                          left: compact ? 0 : 4,
                          child: _impactNode(
                            color: _impactIndicatorColor(<String>[
                              'left_side',
                            ], hasSevereImpact),
                          ),
                        ),
                        Positioned(
                          right: compact ? 0 : 4,
                          child: _impactNode(
                            color: _impactIndicatorColor(<String>[
                              'right_side',
                            ], hasSevereImpact),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          child: _impactNode(
                            color: _impactIndicatorColor(<String>[
                              'rear_left',
                              'rear_right',
                            ], hasSevereImpact),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: centerGap),
                  Expanded(
                    flex: compact ? 7 : 6,
                    child: _impactZoneColumn(
                      <String>['front_right', 'right_side', 'rear_right'],
                      hasSevereImpact,
                      alignRight: true,
                      compact: compact,
                      connectorWidth: connectorWidth,
                      connectorGap: connectorGap,
                      zoneGap: zoneGap,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _impactZoneColumn(
    List<String> zoneKeys,
    bool hasSevereImpact, {
    required bool alignRight,
    required bool compact,
    required double connectorWidth,
    required double connectorGap,
    required double zoneGap,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final zoneKey in zoneKeys) ...[
          Row(
            children: alignRight
                ? <Widget>[
                    SizedBox(
                      width: connectorWidth,
                      child: _impactConnectorLine(),
                    ),
                    SizedBox(width: connectorGap),
                    Expanded(
                      child: _impactZoneCard(
                        _impactZoneCardTitle(zoneKey),
                        isActive:
                            hasSevereImpact &&
                            _activeImpactZones.contains(zoneKey),
                        compact: compact,
                      ),
                    ),
                  ]
                : <Widget>[
                    Expanded(
                      child: _impactZoneCard(
                        _impactZoneCardTitle(zoneKey),
                        isActive:
                            hasSevereImpact &&
                            _activeImpactZones.contains(zoneKey),
                        compact: compact,
                      ),
                    ),
                    SizedBox(width: connectorGap),
                    SizedBox(
                      width: connectorWidth,
                      child: _impactConnectorLine(),
                    ),
                  ],
          ),
          if (zoneKey != zoneKeys.last) SizedBox(height: zoneGap),
        ],
      ],
    );
  }

  Widget _impactConnectorLine() {
    return Container(
      height: 1.2,
      decoration: BoxDecoration(
        color: const Color(0xFFD8DDE3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _impactSimulatorCard() {
    final canInteract = isEvConnected;
    final simulatorTitle = 'Impact Zone Simulator';
    final simulatorSubtitle = canInteract
        ? 'Select impact area (Max 4 zones)'
        : 'Connect EV to enable simulator';
    final selectionLabel = _pendingImpactZones.isEmpty
        ? 'No zones selected'
        : canInteract
        ? 'Ready to simulate selected impact zones'
        : 'Simulator paused while EV is disconnected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECE7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _isWebDemoMode && constraints.maxWidth < 360
              ? 1
              : 2;
          final double buttonAspectRatio = constraints.maxWidth < 430
              ? crossAxisCount == 1
                    ? 4.2
                    : 2.9
              : 3.4;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    simulatorTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                simulatorSubtitle,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                itemCount: _impactZoneOptions.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: buttonAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final zoneKey = _impactZoneOptions[index];
                  final isSelected = _pendingImpactZones.contains(zoneKey);
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: canInteract
                        ? () => _togglePendingImpactZone(zoneKey)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEAF6EE)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF9CD0A1),
                          width: isSelected ? 1.8 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _impactZoneIcon(zoneKey),
                            color: const Color(0xFF2E7D32),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _impactLocationTitle(zoneKey),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6EE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_pendingImpactZones.length}',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectionLabel,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    'Selected: ${_pendingImpactZones.length} / 4',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearImpactSelection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: const BorderSide(color: Color(0xFF72BE7B)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canInteract && _pendingImpactZones.isNotEmpty
                          ? _simulateImpactSelection
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCEE7D1),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        'Simulate Impact',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static const List<String> _impactZoneOptions = <String>[
    'front_left',
    'front_right',
    'left_side',
    'right_side',
    'rear_left',
    'rear_right',
  ];

  String _impactLocationSummary(Iterable<String> zoneKeys) {
    final zones = zoneKeys.toList();
    if (zones.isEmpty) {
      return '--';
    }
    if (zones.length == 1) {
      return _impactLocationTitle(zones.first);
    }
    return '${_impactLocationTitle(zones.first)} +${zones.length - 1} more';
  }

  String _impactLocationTitle(String? zoneKey) {
    switch (zoneKey) {
      case 'front_left':
        return 'Front Left';
      case 'front_right':
        return 'Front Right';
      case 'left_side':
        return 'Left Side';
      case 'right_side':
        return 'Right Side';
      case 'rear_left':
        return 'Rear Left';
      case 'rear_right':
        return 'Rear Right';
      default:
        return '--';
    }
  }

  String _impactZoneCardTitle(String zoneKey) {
    switch (zoneKey) {
      case 'front_left':
        return 'Front\nLeft';
      case 'front_right':
        return 'Front\nRight';
      case 'left_side':
        return 'Left\nSide';
      case 'right_side':
        return 'Right\nSide';
      case 'rear_left':
        return 'Rear\nLeft';
      case 'rear_right':
        return 'Rear\nRight';
      default:
        return '--';
    }
  }

  IconData _impactZoneIcon(String zoneKey) {
    switch (zoneKey) {
      case 'front_left':
      case 'front_right':
        return Icons.car_crash_outlined;
      case 'left_side':
      case 'right_side':
        return Icons.directions_car_filled_outlined;
      case 'rear_left':
      case 'rear_right':
        return Icons.airport_shuttle_outlined;
      default:
        return Icons.adjust_rounded;
    }
  }

  Color _impactIndicatorColor(List<String> zoneKeys, bool hasSevereImpact) {
    if (!isEvConnected) {
      return Colors.orange.shade700;
    }
    final isTriggered =
        hasSevereImpact &&
        zoneKeys.any((zoneKey) => _activeImpactZones.contains(zoneKey));
    return isTriggered ? const Color(0xFFE53935) : const Color(0xFF2E7D32);
  }

  void _togglePendingImpactZone(String zoneKey) {
    if (!isEvConnected) {
      return;
    }

    setState(() {
      if (_pendingImpactZones.contains(zoneKey)) {
        _pendingImpactZones.remove(zoneKey);
        return;
      }
      if (_pendingImpactZones.length < 4) {
        _pendingImpactZones.add(zoneKey);
      }
    });
  }

  void _clearImpactSelection() {
    final shouldResetActiveSimulation =
        impactAutoAlertStatus == 'Simulation Only';

    setState(() {
      _pendingImpactZones.clear();
    });

    if (shouldResetActiveSimulation) {
      _resetImpactSimulation();
    }
  }

  void _simulateImpactSelection() {
    if (!isEvConnected || _pendingImpactZones.isEmpty) {
      return;
    }

    final selectedZones = List<String>.from(_pendingImpactZones);
    setState(() {
      _activeImpactZones
        ..clear()
        ..addAll(selectedZones);
      activeImpactZone = selectedZones.first;
      activeImpactLevel = selectedZones.length >= 4 ? 5 : 4;
      lastImpactAt = DateTime.now();
      lastImpactLabel = AppRepository.severityLabel(activeImpactLevel);
      impactStatus = 'Manual impact simulation active';
      impactAutoAlertStatus = _isWebDemoMode
          ? 'Awaiting confirmation'
          : 'Simulation Only';
      _pendingImpactZones.clear();
    });

    if (_isWebDemoMode) {
      _showEmergencyCountdown(
        title: 'Manual impact alert ready. Cancel if safe.',
        subtitle:
            'Selected zones: ${selectedZones.map(_impactLocationTitle).join(', ')}.',
        impactLevel: activeImpactLevel,
        source: 'manual_remote',
        autoDispatch: activeImpactLevel >= 4,
      );
    }
  }

  Widget _impactZoneCard(
    String title, {
    required bool isActive,
    bool compact = false,
  }) {
    final statusColor = !isEvConnected
        ? Colors.orange.shade700
        : isActive
        ? const Color(0xFFE53935)
        : const Color(0xFF2E7D32);
    final statusText = !isEvConnected
        ? 'No Data'
        : isActive
        ? 'Impact Detected'
        : 'Clear';

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 84 : 88),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFFF2B8B5) : const Color(0xFFE6ECE6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11.0 : 13.6,
                    height: 1.04,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11.8 : 13.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactNode({required Color color}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
    );
  }

  Widget _impactInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isLast ? 8 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEAEDEA))),
      ),
      child: Row(
        children: [
          Icon(
            label == 'Impact Location'
                ? Icons.location_on_outlined
                : label == 'Impact Time'
                ? Icons.access_time_rounded
                : label == 'Monitoring Status'
                ? Icons.verified_user_outlined
                : label == 'Auto Alert'
                ? Icons.verified_user_outlined
                : Icons.notifications_none_rounded,
            color: Colors.grey.shade500,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryMonitoringCard() {
    final isOverheating = batteryTemperature > 45;
    final accentColor = isEvConnected
        ? const Color(0xFF2E7D32)
        : Colors.orange.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full, color: accentColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Battery Pack',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: _showBatteryDetailsDialog,
                child: const Text('View Details'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: _batterySocCard()),
                const SizedBox(width: 12),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      _batteryMiniMetric(
                        'Estimated Range',
                        isEvConnected ? '$estimatedRangeKm km' : '--',
                        Icons.route_rounded,
                      ),
                      const SizedBox(height: 10),
                      _batteryMiniMetric(
                        'Battery Health',
                        isEvConnected ? batteryHealth : 'Disconnected',
                        Icons.health_and_safety_rounded,
                      ),
                      const SizedBox(height: 10),
                      _batteryMiniMetric(
                        'Time to Full',
                        isEvConnected
                            ? (batteryLevel >= 0.95 ? 'Almost full' : '1h 24m')
                            : '--',
                        Icons.schedule_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.85,
            children: [
              _batteryMetricTile(
                'Battery Voltage',
                isEvConnected ? '$batteryVoltage V' : '--',
              ),
              _batteryMetricTile(
                'Battery Current',
                isEvConnected ? '${batteryCurrent.toStringAsFixed(1)} A' : '--',
              ),
              _batteryMetricTile(
                'Battery Temp.',
                isEvConnected
                    ? '${batteryTemperature.toStringAsFixed(0)} C'
                    : '--',
                warning: isEvConnected && isOverheating,
              ),
              _batteryMetricTile(
                'Safety Status',
                isEvConnected ? batterySafetyStatus : 'Disconnected',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBF7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0EAE0)),
            ),
            child: Column(
              children: [
                _statusLine(
                  'Charging Status',
                  !isEvConnected
                      ? 'Disconnected'
                      : isOverheating
                      ? 'Stop charging immediately'
                      : chargingStatus,
                  !isEvConnected
                      ? Colors.orange.shade700
                      : isOverheating
                      ? Colors.red
                      : Colors.green,
                ),
                _statusLine(
                  'Charging Port',
                  isEvConnected ? chargingPortStatus : 'No live data',
                  isEvConnected ? Colors.green : Colors.orange.shade700,
                ),
                _statusLine(
                  'Time to Full',
                  isEvConnected
                      ? (batteryLevel >= 0.95 ? 'Almost full' : '1h 24m')
                      : '--',
                  accentColor,
                ),
                _statusLine(
                  'Regenerative Braking',
                  isEvConnected ? 'Active' : 'Inactive',
                  accentColor,
                ),
                _statusLine(
                  'Thermal Cooling',
                  isEvConnected ? 'Active' : 'Standby',
                  accentColor,
                ),
              ],
            ),
          ),
          if (!isEvConnected) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD4A3)),
              ),
              child: const Text(
                'Battery pack is disconnected. Reconnect EV to resume live charging, thermal, and voltage data.',
                style: TextStyle(
                  color: Color(0xFF9A5B00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (isOverheating) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Battery Overheating Detected\nRecommendation: Stop charging and inspect battery.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _batterySocCard() {
    final cardColors = isEvConnected
        ? const [Color(0xFF2E7D32), Color(0xFF63A85C)]
        : [Colors.orange.shade700, const Color(0xFFF1A95A)];
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'State of Charge',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEvConnected ? '${(batteryLevel * 100).round()}%' : '--',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEvConnected ? 'Live battery feed' : 'Reconnect EV for live data',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: isEvConnected ? batteryLevel : 0,
              minHeight: 10,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryMiniMetric(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EAE0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryMetricTile(
    String title,
    String value, {
    bool warning = false,
  }) {
    final color = warning ? Colors.red : const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? Colors.red.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warning ? Colors.red.shade100 : const Color(0xFFE8ECE8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveSystemStatusPanel() {
    final title = 'EVSmart+ IoT Architecture';
    final accentLine = 'Sensor -> Cloud -> Intelligent Action';
    final summary =
        'Sensors collect data -> Gateway processes -> Cloud analyzes -> System responds.';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                accentLine,
                style: TextStyle(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: TextStyle(color: Colors.grey.shade700, height: 1.32),
              ),
              const SizedBox(height: 12),
              _flowStep(
                Icons.wifi_tethering_rounded,
                '1. Sensor Input',
                'Real-time vehicle data collection from battery, tire, GPS, impact, and temperature.',
              ),
              _flowStep(
                Icons.memory_rounded,
                '2. Gateway Processing',
                'Microcontroller analyzes sensor data in real-time.',
              ),
              _flowStep(
                Icons.cloud_queue_rounded,
                '3. Cloud Sync',
                'Real-time cloud monitoring and live Firebase updates.',
              ),
              _flowStep(
                Icons.warning_amber_rounded,
                '4. AI Decision & Alerts',
                'Triggers alerts based on impact severity.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSmartServicesCard(),
      ],
    );
  }

  Widget _buildSmartServicesCard() {
    final features = <Map<String, dynamic>>[
      {
        'id': 'charging',
        'title': 'Charging\nStation Finder',
        'subtitle': 'Nearby chargers & availability',
        'icon': Icons.ev_station_rounded,
        'accent': const Color(0xFF2E7D32),
        'tint': const Color(0xFFF1FBF3),
      },
      {
        'id': 'manual_alert',
        'title': 'Manual\nAlert Hub',
        'subtitle': 'Trigger emergency manually',
        'icon': Icons.notification_important_rounded,
        'accent': const Color(0xFFD93025),
        'tint': const Color(0xFFFFF3F2),
      },
      {
        'id': 'alerts_settings',
        'title': 'Alerts &\nSettings',
        'subtitle': 'Customize preferences',
        'icon': Icons.notifications_rounded,
        'accent': const Color(0xFF1565C0),
        'tint': const Color(0xFFF2F7FF),
      },
      {
        'id': 'assistance',
        'title': 'Assistance &\nMessaging',
        'subtitle': 'Connect with nearby help',
        'icon': Icons.forum_rounded,
        'accent': const Color(0xFF6A1B9A),
        'tint': const Color(0xFFF7F1FF),
      },
      {
        'id': 'rewards',
        'title': 'Rewards &\nDonations',
        'subtitle': 'Earn points & give back',
        'icon': Icons.card_giftcard_rounded,
        'accent': const Color(0xFFEF6C00),
        'tint': const Color(0xFFFFF5EA),
      },
      {
        'id': 'profile',
        'title': 'Profile &\nSettings',
        'subtitle': 'Manage account & app',
        'icon': Icons.settings_rounded,
        'accent': const Color(0xFF00796B),
        'tint': const Color(0xFFF0FBF8),
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color(0x14000000),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: const Color(0xFFE3EAE4)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Smart Services & Control',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: const Color(0xFFE3EAE4)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Quick access to charging, alerts, support, and personal controls.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12.4,
                height: 1.28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final tileAspectRatio = compact ? 0.82 : 0.9;

              return GridView.builder(
                itemCount: features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: tileAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return _buildFeatureTile(
                    title: feature['title'] as String,
                    icon: feature['icon'] as IconData,
                    accentColor: feature['accent'] as Color,
                    backgroundColor: feature['tint'] as Color,
                    onTap: () => _showFeatureDialog(feature['id'] as String),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.16)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 8,
                      color: Color(0x10000000),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  height: 1.12,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFeatureDialog(String featureId) async {
    late final String title;
    late final IconData icon;
    late final Color accentColor;
    late final Color tintColor;
    int selectedAlertLevel = 4;

    switch (featureId) {
      case 'charging':
        title = 'Charging Station Finder';
        icon = Icons.ev_station_rounded;
        accentColor = const Color(0xFF2E7D32);
        tintColor = const Color(0xFFF1FBF3);
        break;
      case 'manual_alert':
        title = 'Manual Alert Hub';
        icon = Icons.notification_important_rounded;
        accentColor = const Color(0xFFD93025);
        tintColor = const Color(0xFFFFF3F2);
        break;
      case 'alerts_settings':
        title = 'Alerts & Settings';
        icon = Icons.notifications_rounded;
        accentColor = const Color(0xFF1565C0);
        tintColor = const Color(0xFFF2F7FF);
        break;
      case 'assistance':
        title = 'Assistance & Messaging';
        icon = Icons.forum_rounded;
        accentColor = const Color(0xFF6A1B9A);
        tintColor = const Color(0xFFF7F1FF);
        break;
      case 'rewards':
        title = 'Rewards & Donations';
        icon = Icons.card_giftcard_rounded;
        accentColor = const Color(0xFFEF6C00);
        tintColor = const Color(0xFFFFF5EA);
        break;
      default:
        title = 'Profile & Settings';
        icon = Icons.settings_rounded;
        accentColor = const Color(0xFF00796B);
        tintColor = const Color(0xFFF0FBF8);
        break;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget dialogBody;

            switch (featureId) {
              case 'charging':
                dialogBody = Column(
                  children: [
                    _buildDialogRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: accentColor,
                      label: 'Total Chargers',
                      value: '24',
                      valueColor: accentColor,
                    ),
                    _buildDialogRow(
                      icon: Icons.battery_charging_full_rounded,
                      iconColor: accentColor,
                      label: 'Available Slots',
                      value: '7',
                      valueColor: accentColor,
                    ),
                    _buildDialogRow(
                      icon: Icons.near_me_rounded,
                      iconColor: accentColor,
                      label: 'Nearest Distance',
                      value: '1.2 km',
                      valueColor: accentColor,
                    ),
                    _buildDialogRow(
                      icon: Icons.location_on_outlined,
                      iconColor: accentColor,
                      label: 'Location',
                      value: city.isEmpty ? 'Kuala Lumpur' : city,
                      valueColor: accentColor,
                    ),
                    _buildDialogRow(
                      icon: Icons.map_outlined,
                      iconColor: accentColor,
                      label: 'Navigate',
                      value: 'Open in Maps',
                      valueColor: accentColor,
                      showChevron: true,
                    ),
                  ],
                );
                break;
              case 'manual_alert':
                dialogBody = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Alert Level',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAlertLevelButtons(
                      selectedLevel: selectedAlertLevel,
                      accentColor: accentColor,
                      onSelected: (level) {
                        setDialogState(() {
                          selectedAlertLevel = level;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD5D2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_hospital_rounded,
                            color: Color(0xFFD93025),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Level 4-5',
                                  style: TextStyle(
                                    color: Color(0xFFD93025),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sent to nearest hospitals based on current location.',
                                  style: TextStyle(height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE0B2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            color: Color(0xFFEF6C00),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Level 1-3',
                                  style: TextStyle(
                                    color: Color(0xFFEF6C00),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sent to service / insurance or nearby assistance.',
                                  style: TextStyle(height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3FBF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCECDD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emergency_rounded,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ambulance support nearby is available when emergency response is needed.',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                break;
              case 'alerts_settings':
                dialogBody = Column(
                  children: [
                    _buildDialogRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: accentColor,
                      label: 'Auto Alert',
                      value: 'ON',
                      valueColor: const Color(0xFF2E7D32),
                      trailingWidth: 94,
                    ),
                    _buildDialogRow(
                      icon: Icons.tune_rounded,
                      iconColor: accentColor,
                      label: 'Notification Control',
                      trailingWidth: 94,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.volume_up_rounded,
                      iconColor: accentColor,
                      label: 'Alert Sound',
                      value: 'Default',
                      trailingWidth: 94,
                    ),
                    _buildDialogRow(
                      icon: Icons.vibration_rounded,
                      iconColor: accentColor,
                      label: 'Vibration',
                      value: 'ON',
                      valueColor: const Color(0xFF2E7D32),
                      trailingWidth: 94,
                    ),
                    _buildDialogRow(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: accentColor,
                      label: 'Safety Preferences',
                      trailingWidth: 94,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.do_not_disturb_alt_rounded,
                      iconColor: accentColor,
                      label: 'Do Not Disturb',
                      value: 'OFF',
                      trailingWidth: 94,
                    ),
                  ],
                );
                break;
              case 'assistance':
                dialogBody = Column(
                  children: [
                    _buildDialogRow(
                      icon: Icons.support_agent_rounded,
                      iconColor: accentColor,
                      label: 'Technician Support',
                      value: '5 nearby',
                      valueColor: const Color(0xFF2E7D32),
                      trailingWidth: 102,
                    ),
                    _buildDialogRow(
                      icon: Icons.local_hospital_rounded,
                      iconColor: accentColor,
                      label: 'Hospital Contact',
                      value: '3 nearby',
                      valueColor: const Color(0xFF2E7D32),
                      trailingWidth: 102,
                    ),
                    _buildDialogRow(
                      icon: Icons.medical_services_rounded,
                      iconColor: accentColor,
                      label: 'Ambulance Support',
                      value: '2 nearby',
                      valueColor: const Color(0xFF2E7D32),
                      trailingWidth: 102,
                    ),
                    _buildDialogRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: accentColor,
                      label: 'Real-time Messaging',
                      trailingWidth: 102,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.share_location_rounded,
                      iconColor: accentColor,
                      label: 'Share Live Location',
                      trailingWidth: 102,
                      showChevron: true,
                    ),
                  ],
                );
                break;
              case 'rewards':
                dialogBody = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogRow(
                      icon: Icons.stars_rounded,
                      iconColor: accentColor,
                      label: 'Check-in Points',
                      value: '120 pts',
                      valueColor: accentColor,
                      trailingWidth: 100,
                    ),
                    _buildDialogRow(
                      icon: Icons.redeem_rounded,
                      iconColor: accentColor,
                      label: 'Redeem Rewards',
                      trailingWidth: 100,
                      showChevron: true,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Donation options',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDialogRow(
                      icon: Icons.school_rounded,
                      iconColor: accentColor,
                      label: 'Education Support',
                      trailingWidth: 100,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.favorite_rounded,
                      iconColor: accentColor,
                      label: 'Cancer Patient Support',
                      trailingWidth: 100,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.psychology_alt_rounded,
                      iconColor: accentColor,
                      label: 'Mental Health Support',
                      trailingWidth: 100,
                      showChevron: true,
                    ),
                  ],
                );
                break;
              default:
                dialogBody = Column(
                  children: [
                    _buildDialogRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: accentColor,
                      label: 'Edit Profile',
                      trailingWidth: 96,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.directions_car_rounded,
                      iconColor: accentColor,
                      label: 'Vehicle Information',
                      trailingWidth: 96,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: accentColor,
                      label: 'Privacy & Security',
                      trailingWidth: 96,
                      showChevron: true,
                    ),
                    _buildDialogRow(
                      icon: Icons.light_mode_rounded,
                      iconColor: accentColor,
                      label: 'Theme',
                      value: 'Light',
                      trailingWidth: 96,
                    ),
                    _buildDialogRow(
                      icon: Icons.language_rounded,
                      iconColor: accentColor,
                      label: 'Language',
                      value: 'English',
                      trailingWidth: 96,
                    ),
                    _buildDialogRow(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFD93025),
                      label: 'Logout',
                      labelColor: const Color(0xFFD93025),
                      trailingWidth: 96,
                      showChevron: true,
                    ),
                  ],
                );
                break;
            }

            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 28,
                        color: Color(0x1A000000),
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: tintColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: accentColor, size: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              splashRadius: 20,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 10),
                        dialogBody,
                        const SizedBox(height: 18),
                        Center(
                          child: SizedBox(
                            width: 130,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    Color? valueColor,
    Color? labelColor,
    bool showChevron = false,
    double trailingWidth = 84,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13.6,
              ),
            ),
          ),
          if (value != null)
            SizedBox(
              width: trailingWidth,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.2,
                ),
              ),
            ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: valueColor ?? iconColor,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertLevelButtons({
    required int selectedLevel,
    required Color accentColor,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(5, (index) {
        final level = index + 1;
        final isSelected = level == selectedLevel;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 42,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accentColor : const Color(0xFFE0E3E8),
              ),
            ),
            child: Text(
              '$level',
              style: TextStyle(
                color: isSelected ? accentColor : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _flowStep(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EAE0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13.2,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showBatteryDetailsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'EV Battery Details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogStatusLine(
                'State of Charge',
                '${(batteryLevel * 100).round()}%',
              ),
              _dialogStatusLine('Estimated Range', '$estimatedRangeKm km'),
              _dialogStatusLine('Voltage', '$batteryVoltage V'),
              _dialogStatusLine(
                'Current',
                '${batteryCurrent.toStringAsFixed(1)} A',
              ),
              _dialogStatusLine(
                'Battery Temperature',
                '${batteryTemperature.toStringAsFixed(0)} C',
              ),
              _dialogStatusLine('Charging Status', chargingStatus),
              const SizedBox(height: 12),
              Text(
                'Why EV-specific: the traction battery, charging state, thermal safety, and range are the main differences from petrol cars. EVSmart+ monitors these values alongside impact detection.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTireDetailsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Tire System Details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogStatusLine('Front Left Tire', '$tirePressurePsi PSI'),
              _dialogStatusLine('Front Right Tire', '$tirePressurePsi PSI'),
              _dialogStatusLine('Rear Left Tire', '$tirePressurePsi PSI'),
              _dialogStatusLine('Rear Right Tire', '$tirePressurePsi PSI'),
              const SizedBox(height: 12),
              Text(
                'Normal EV tire pressure range: 32 to 36 PSI when the tires are cool.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                'Below 30 PSI usually means the tire is under-inflated and should be checked soon.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                'Above 40 PSI can be too high for normal daily driving and may reduce comfort or grip.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDrivingDetailsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Driving Sensor Details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogStatusLine('Speed', isEvConnected ? '62 km/h' : '--'),
              _dialogStatusLine(
                'Distance Today',
                isEvConnected ? '12.6 km' : '--',
              ),
              _dialogStatusLine(
                'GPS Latitude',
                isEvConnected
                    ? currentLocation.latitude.toStringAsFixed(4)
                    : '--',
              ),
              _dialogStatusLine(
                'GPS Longitude',
                isEvConnected
                    ? currentLocation.longitude.toStringAsFixed(4)
                    : '--',
              ),
              const SizedBox(height: 12),
              Text(
                'Driving sensors help the app estimate trip movement, live location, and nearby charger or support routing.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSafetyDetailsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Safety Sensor Details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogStatusLine(
                'Impact Sensor',
                isEvConnected
                    ? (activeImpactLevel >= 4 ? 'Impact detected' : 'Clear')
                    : '--',
              ),
              _dialogStatusLine(
                'Brake / Sudden Stop',
                isEvConnected ? '$suddenBrakingEvents events' : '--',
              ),
              _dialogStatusLine(
                'Door / Collision',
                isEvConnected ? 'Closed' : '--',
              ),
              const SizedBox(height: 12),
              Text(
                'These safety sensors support impact detection, harsh stop review, and door or collision checks during emergency monitoring.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogStatusLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _connectDefaultEvSimulation() {
    _connectEvSimulation(model: selectedEvModel, method: evConnectionMethod);
  }

  void _connectEvSimulation({required String model, required String method}) {
    setState(() {
      isEvConnected = true;
      selectedEvModel = model;
      evConnectionMethod = method;
      vehicleConnectionStatus = 'Connected to $model';
      chargingPortStatus = 'Linked to charging controller';
      inverterStatus = 'Synced';
      driveMode = method == 'Manual basic EV mode'
          ? 'Basic EV'
          : 'Normal';
      estimatedRangeKm = method == 'Manual basic EV mode' ? 212 : 294;
      batterySafetyStatus = 'Normal';
      lastSystemCheckAt = DateTime.now();
      disconnectedAt = null;
      activeImpactLevel = 0;
      activeImpactZone = null;
      _activeImpactZones.clear();
      _pendingImpactZones.clear();
      impactStatus = _defaultImpactStatus;
      lastImpactLabel = 'No impact';
      lastImpactAt = null;
      impactAutoAlertStatus = 'Standby';
      lastEvSnapshot =
          'Battery ${(batteryLevel * 100).round()}%, range $estimatedRangeKm km, tire $tirePressurePsi PSI';
    });

    _showEvConnectedDialog(model: model, method: method);
  }

  Future<void> _showEvConnectedDialog({
    required String model,
    required String method,
  }) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'EV Connected',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _connectionCheckRow('Vehicle selected', model),
              _connectionCheckRow('Connection method', method),
              _connectionCheckRow('Sensors connected', 'Battery, tire, GPS, impact'),
              _connectionCheckRow('Cloud connected', 'Firebase live sync'),
              _connectionCheckRow('Refresh interval', 'Every 15 seconds'),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Start Monitoring'),
            ),
          ],
        );
      },
    );
  }

  Widget _connectionCheckRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _disconnectEvSimulation() {
    setState(() {
      isEvConnected = false;
      disconnectedAt = DateTime.now();
      lastSystemCheckAt = disconnectedAt!;
      vehicleConnectionStatus = 'Disconnected - cached EV data shown';
      chargingPortStatus = 'Last known: $chargingPortStatus';
      inverterStatus = 'Cached: $inverterStatus';
      activeImpactLevel = 0;
      activeImpactZone = null;
      _activeImpactZones.clear();
      _pendingImpactZones.clear();
      impactStatus = 'Monitoring paused';
      lastImpactLabel = 'No impact';
      lastImpactAt = null;
      impactAutoAlertStatus = 'Inactive';
      lastEvSnapshot =
          'Battery ${(batteryLevel * 100).round()}%, range $estimatedRangeKm km, tire $tirePressurePsi PSI';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('EV disconnected. Showing last synced vehicle data.'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class LatLngState {
  const LatLngState({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
