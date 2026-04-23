import 'dart:async';
import 'dart:convert';

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
  int selectedTab = 0;

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
  LatLngState currentLocation = const LatLngState(
    latitude: 3.1390,
    longitude: 101.6869,
  );

  late final ImpactDetectionService _impactService;
  bool _isImpactDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    _impactService.start();
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
              'impact_detected_by': 'Phone accelerometer IoT simulation',
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
              'impact_detected_by': 'Phone accelerometer IoT simulation',
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
    });

    if (!emergencyTriggered && impactLevel <= 3) {
      await NotificationService.showImpactDetectedNotification(
        level: impactLevel,
        magnitude: accelerationMagnitude ?? 0,
        body:
            'A bump or vehicle impact was detected. Open EVSmart+ to review it.',
      );
    }

    _showHelpOnTheWay(emergencyTriggered, alert['impact_label'].toString());
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
                    value: seconds / 5,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This simulates vehicle IoT impact sensors using the phone accelerometer.',
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
    _isImpactDialogVisible = false;
    if (cancelled && mounted) {
      setState(() {
        impactStatus = 'Monitoring active';
        lastImpactLabel = 'No impact';
      });
    }
  }

  void _showHelpOnTheWay(bool emergencyTriggered, String severityLabel) {
    final nearestHospital = AssistDirectory.nearestProvider(
      AssistDirectory.healthProviders,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
    );

    showDialog<void>(
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
      bottomNavigationBar: _buildBottomNav(bottomPadding),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
          _liveSystemStatusPanel(),
          const SizedBox(height: 16),
          _emergencyButton(),
          const SizedBox(height: 20),
          const Text(
            'Activity Feed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildActivityFeed(),
          const SizedBox(height: 20),
          const Text(
            'Live Updates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildLiveUpdates(),
        ],
      ),
    );
  }

  Widget _evConnectionCard() {
    final linkColor = isEvConnected ? Colors.green : Colors.orange;
    final lastSyncLabel = isEvConnected
        ? 'Live now - ${_formatDate(lastSystemCheckAt)}'
        : 'Last synced ${_formatDate(disconnectedAt ?? lastSystemCheckAt)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                    const Text(
                      'Connect EV',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: [
              _infoPill(
                Icons.sensors_rounded,
                isEvConnected ? 'Sensors linked' : 'Sensors cached',
                isEvConnected ? 'Battery, tire, GPS, impact' : lastEvSnapshot,
                linkColor,
              ),
              _infoPill(
                Icons.cloud_sync_outlined,
                isEvConnected ? 'Cloud connected' : 'Cloud paused',
                isEvConnected ? 'Firebase sync every 15s' : lastSyncLabel,
                linkColor,
              ),
              _infoPill(
                Icons.route_rounded,
                'Estimated range',
                '$estimatedRangeKm km',
                const Color(0xFF2E7D32),
              ),
              _infoPill(
                Icons.speed_rounded,
                'Drive mode',
                driveMode,
                const Color(0xFF2E7D32),
              ),
            ],
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
                  isEvConnected ? Icons.link_off_rounded : Icons.ev_station,
                ),
                label: Text(isEvConnected ? 'Disconnect EV' : 'Connect EV'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionSummaryStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.cloud_upload_outlined,
              isEvConnected ? 'Connected' : 'Disconnected',
              isEvConnected ? 'Live data from cloud' : 'Showing cached data',
              isEvConnected ? Colors.green : Colors.orange,
            ),
          ),
          Expanded(
            child: _summaryItem(
              Icons.history_rounded,
              'Last Updated',
              _formatDate(lastSystemCheckAt),
              const Color(0xFF2E7D32),
            ),
          ),
          Expanded(
            child: _summaryItem(
              Icons.timer_outlined,
              'Auto Sync',
              isEvConnected ? 'Every 15s' : 'Paused',
              isEvConnected ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 25),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _carHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/ic_car_background.png',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: .55),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.center,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Stay safe & drive smart.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  impactStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vehicle Health Sensors',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isEvConnected
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isEvConnected ? 'Live' : 'Cached',
                  style: TextStyle(
                    color: isEvConnected
                        ? const Color(0xFF2E7D32)
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _sensorTile(
                Icons.tire_repair_rounded,
                'Tire Pressure',
                '$tirePressurePsi PSI',
                'Normal',
              ),
              _sensorTile(
                Icons.device_thermostat_rounded,
                'Tire Temp.',
                '$tireTemperature C',
                'Normal',
              ),
              _sensorTile(
                Icons.settings_input_component_rounded,
                'Motor Temp.',
                '$motorTemperature C',
                'Normal',
              ),
              _sensorTile(
                Icons.memory_rounded,
                'Inverter',
                inverterStatus,
                'Synced',
              ),
              _sensorTile(
                Icons.security_rounded,
                'Impact Sensor',
                lastImpactLabel,
                impactStatus,
              ),
              _sensorTile(
                Icons.location_on_rounded,
                'GPS Location',
                '${currentLocation.latitude.toStringAsFixed(4)}, ${currentLocation.longitude.toStringAsFixed(4)}',
                city,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sensorTile(
    IconData icon,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emergencyButton() {
    return InkWell(
      onTap: () {
        _showEmergencyCountdown(
          title: 'Potential accident detected. Cancel if safe.',
          subtitle:
              'Emergency assist has been requested. Cancel within 5 seconds if this was accidental.',
          impactLevel: 5,
          source: 'manual_sos',
          autoDispatch: true,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Emergency Assist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batteryMonitoringCard() {
    final isOverheating = batteryTemperature > 45;
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
              const Icon(Icons.battery_charging_full, color: Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Battery Pack Overview',
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
          Row(
            children: [
              Expanded(child: _batterySocCard()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _batteryMiniMetric(
                      'Estimated Range',
                      '$estimatedRangeKm km',
                      Icons.route_rounded,
                    ),
                    const SizedBox(height: 10),
                    _batteryMiniMetric(
                      'Battery Health',
                      batteryHealth,
                      Icons.health_and_safety_rounded,
                    ),
                  ],
                ),
              ),
            ],
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
              _batteryMetricTile('Battery Voltage', '$batteryVoltage V'),
              _batteryMetricTile(
                'Battery Current',
                '${batteryCurrent.toStringAsFixed(1)} A',
              ),
              _batteryMetricTile(
                'Battery Temp.',
                '${batteryTemperature.toStringAsFixed(0)} C',
                warning: isOverheating,
              ),
              _batteryMetricTile('Safety Status', batterySafetyStatus),
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
                  isOverheating ? 'Stop charging immediately' : chargingStatus,
                  isOverheating ? Colors.red : Colors.green,
                ),
                _statusLine('Charging Port', chargingPortStatus, Colors.green),
                _statusLine(
                  'Time to Full',
                  batteryLevel >= 0.95 ? 'Almost full' : '1h 24m',
                  const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
          if (isOverheating) ...[
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
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF63A85C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'State of Charge',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${(batteryLevel * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: batteryLevel,
              minHeight: 8,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EAE0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
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
    return Container(
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
          const Text(
            'EVSmart+ IoT Data Flow',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Prototype flow: external EV sensors or OBD/CAN reader -> microcontroller gateway -> cloud -> EVSmart+ dashboard.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 12),
          _flowStep(
            Icons.sensors_rounded,
            '1. Sensor Input',
            'Battery voltage/current/temp, tire pressure, GPS, impact, cabin temp.',
          ),
          _flowStep(
            Icons.developer_board_rounded,
            '2. Gateway Processing',
            'ESP32/OBD-II/CAN demo gateway applies threshold rules.',
          ),
          _flowStep(
            Icons.cloud_done_rounded,
            '3. Cloud Sync',
            'Firebase receives updates every 15 seconds for live monitoring.',
          ),
          _flowStep(
            Icons.emergency_share_rounded,
            '4. Auto Action',
            'Level 4/5 impact goes to hospital dashboard; EV issues suggest charger or technician.',
          ),
        ],
      ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.3),
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

  Widget _buildActivityFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamAlerts(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <Map<String, dynamic>>[];
        if (alerts.isEmpty) {
          return _activity('System Check Completed', 'Monitoring');
        }

        return Column(
          children: alerts.take(3).map((alert) {
            return _activity(
              alert['title']?.toString() ?? 'Alert synced',
              _formatTimeLabel(alert['timestamp']),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _activity(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          Text(time, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLiveUpdates() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamNotifications(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        final display = items.take(4).toList();
        if (display.isEmpty) {
          return _liveFeed(
            'Notifications will appear here once alerts are synced.',
          );
        }
        return Column(
          children: display
              .map((item) => _liveFeed(item['message']?.toString() ?? '-'))
              .toList(),
        );
      },
    );
  }

  Widget _liveFeed(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Row(
        children: [
          const Icon(Icons.newspaper, color: Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
      driveMode = method == 'Manual basic EV mode' ? 'Basic EV' : 'Normal';
      estimatedRangeKm = method == 'Manual basic EV mode' ? 212 : 294;
      batterySafetyStatus = 'Normal';
      lastSystemCheckAt = DateTime.now();
      disconnectedAt = null;
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
              _connectionCheckRow(
                'Sensors connected',
                'Battery, tire, GPS, impact',
              ),
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
      lastEvSnapshot =
          'Battery ${(batteryLevel * 100).round()}%, range $estimatedRangeKm km, tire $tirePressurePsi PSI';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('EV disconnected. Showing last synced vehicle data.'),
      ),
    );
  }

  Widget _buildBottomNav(double bottomPadding) {
    return Container(
      height: 85 + bottomPadding,
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          buildTab(Icons.home, 'Home', 0),
          buildTab(Icons.ev_station, 'Charge', 1),
          buildTab(Icons.warning, 'Alert', 2),
          buildTab(Icons.notifications, 'Noti', 3),
          buildTab(Icons.card_giftcard, 'Rewards', 4),
        ],
      ),
    );
  }

  Widget buildTab(IconData icon, String label, int index) {
    final isActive = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() => selectedTab = index);

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
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF2E7D32) : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF2E7D32) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeLabel(Object? value) {
    final timestamp = value?.toString();
    final date = timestamp == null ? null : DateTime.tryParse(timestamp);
    if (date == null) {
      return 'Now';
    }
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
