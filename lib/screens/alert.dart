import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_repository.dart';
import '../services/impact_detection_service.dart';
import 'app_header.dart';
import 'charge.dart';
import 'global_search.dart';
import 'home_driver.dart';
import 'noti.dart';
import 'rewards.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _softGreen = Color(0xFFE8F5E9);
  static const Color _surface = Color(0xFFF3F4F6);

  late final ImpactDetectionService _impactDetectionService;

  int selectedTab = 2;
  String _statusMessage = 'Monitoring active';
  DateTime? _selectedHistoryDate;
  bool _showingImpactDialog = false;

  @override
  void initState() {
    super.initState();
    // This page now subscribes to the accelerometer-based monitoring service
    // so sensor-triggered impacts immediately restore the missing alert popup.
    _impactDetectionService = ImpactDetectionService(
      onImpact: _handleDetectedImpact,
    );
    _impactDetectionService.start();
  }

  @override
  void dispose() {
    _impactDetectionService.stop();
    super.dispose();
  }

  Future<void> _handleDetectedImpact(ImpactEvent event) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Impact detected. Preparing incident response.';
    });

    await _triggerAlert(
      event.level,
      source: 'automatic_impact_detection',
      title: 'Automatic impact detected',
      accelerationMagnitude: event.magnitude,
      detectedAt: event.detectedAt,
      vehicleStatusOverride:
          '${_vehicleConditionForLevel(event.level)} ${event.description}',
    );
  }

  Future<void> _triggerManualAlert(int level) async {
    await _triggerAlert(
      level,
      source: 'manual_alert_page',
      title: level == 5 ? 'SOS emergency triggered' : 'Manual alert triggered',
    );
  }

  Future<void> _triggerAlert(
    int level, {
    required String source,
    required String title,
    double? accelerationMagnitude,
    DateTime? detectedAt,
    String? vehicleStatusOverride,
  }) async {
    final position = await _resolvePosition();
    final latitude = position?.latitude ?? 3.1390;
    final longitude = position?.longitude ?? 101.6869;
    final locationName = AppRepository.inferLocationName(latitude, longitude);
    final roadName = AppRepository.inferRoadName(latitude, longitude);
    final locationLabel = '$locationName - $roadName';
    final emergencyStatus = _emergencyStatusForLevel(level);
    final vehicleCondition =
        vehicleStatusOverride ?? _vehicleConditionForLevel(level);
    final timestamp = detectedAt ?? DateTime.now();

    await AppRepository.createAlert(
      impactLevel: level,
      vehicleStatus: vehicleCondition,
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: level >= 4,
      source: source,
      title: title,
      accidentStatus: emergencyStatus,
      accelerationMagnitude: accelerationMagnitude,
      extraData: {
        'severity': _severityTitle(level),
        'vehicle_condition': vehicleCondition,
        'location': locationLabel,
        'status': emergencyStatus,
        'timestamp': timestamp.toIso8601String(),
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = _statusMessageForLevel(level);
    });

    await showImpactAlert(
      level,
      locationLabel: locationLabel,
      emergencyStatus: emergencyStatus,
      vehicleCondition: vehicleCondition,
      detectedAt: timestamp,
    );
  }

  Future<Position?> _resolvePosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _cancelLatestAlert(List<Map<String, dynamic>> alerts) async {
    if (alerts.isEmpty) {
      return;
    }
    final latest = alerts.first;
    final alertId = latest['alert_id']?.toString();
    if (alertId == null || alertId.isEmpty) {
      return;
    }

    await AppRepository.updateAlert(alertId, {
      'status': 'Cancelled by driver',
      'emergency_triggered': false,
      'vehicle_status': 'Driver cancelled active emergency response',
      'vehicle_condition': 'Driver confirmed situation is stable',
    });

    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = 'Latest emergency flow cancelled';
    });
  }

  // Shared popup flow for automatic impact detection and manual emergency
  // controls. This restores the missing showDialog behavior for impact events.
  Future<void> showImpactAlert(
    int level, {
    required String locationLabel,
    required String emergencyStatus,
    required String vehicleCondition,
    required DateTime detectedAt,
  }) async {
    if (!mounted || _showingImpactDialog) {
      return;
    }

    _showingImpactDialog = true;
    final dispatchFuture = Future<void>.delayed(const Duration(seconds: 2));

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: FutureBuilder<void>(
                future: dispatchFuture,
                builder: (context, snapshot) {
                  final dispatching =
                      snapshot.connectionState != ConnectionState.done;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _severityColor(level).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: _severityColor(level),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _severityTitle(level),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _popupMessage(level),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogLine('Vehicle Condition', vehicleCondition),
                            _buildDialogLine('Emergency Status', emergencyStatus),
                            _buildDialogLine('Location', locationLabel),
                            _buildDialogLine(
                              'Time',
                              _formatTime(detectedAt.toIso8601String()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (dispatching) ...[
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                level >= 4
                                    ? 'Dispatching emergency response...'
                                    : 'Syncing incident log and driver monitoring...',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.check_circle_rounded,
                              color: _severityColor(level),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Alert popup confirmed and incident saved to Firebase.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            level >= 4
                                ? 'Close Alert'
                                : 'Continue Monitoring',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      _showingImpactDialog = false;
    }
  }

  Widget _buildDialogLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _severityTitle(int level) {
    switch (level) {
      case 1:
        return 'Level 1 - Minor vibration';
      case 2:
        return 'Level 2 - Light impact';
      case 3:
        return 'Level 3 - Significant impact';
      case 4:
        return 'Level 4 - Serious accident';
      case 5:
        return 'Level 5 - Critical emergency';
      default:
        return 'No active impact';
    }
  }

  Color _severityColor(int level) {
    if (level >= 4) {
      return Colors.red.shade700;
    }
    if (level == 3) {
      return Colors.orange.shade700;
    }
    if (level >= 1) {
      return _primaryGreen;
    }
    return Colors.grey.shade600;
  }

  String _popupMessage(int level) {
    if (level <= 2) {
      return 'Alert logged. Monitoring vehicle condition.';
    }
    if (level == 3) {
      return 'Impact detected. Monitoring driver condition.';
    }
    if (level == 4) {
      return 'Serious accident detected. Ambulance notification sent.';
    }
    return 'Critical emergency detected. Help is on the way.';
  }

  String _vehicleConditionForLevel(int level) {
    switch (level) {
      case 1:
        return 'Minor vibration recorded. Continue monitoring vehicle systems.';
      case 2:
        return 'Light impact recorded. Check the vehicle body and battery housing.';
      case 3:
        return 'Significant impact detected. Driver and vehicle inspection required.';
      case 4:
        return 'Critical crash detected. Emergency support and medical review required.';
      case 5:
        return 'Severe vehicle damage detected. Immediate life-safety response required.';
      default:
        return 'All safety systems normal.';
    }
  }

  String _emergencyStatusForLevel(int level) {
    if (level <= 2) {
      return 'Alert logged for monitoring';
    }
    if (level == 3) {
      return 'Driver condition under observation';
    }
    if (level == 4) {
      return 'Ambulance notification sent';
    }
    return 'Critical emergency dispatch activated';
  }

  String _statusMessageForLevel(int level) {
    if (level <= 2) {
      return 'Low severity incident synced to Firebase';
    }
    if (level == 3) {
      return 'Moderate impact logged for driver monitoring';
    }
    return 'Emergency monitoring and hospital response activated';
  }

  String _alertTypeForLevel(int level) {
    if (level >= 4) {
      return 'Emergency Incident';
    }
    if (level == 3) {
      return 'Impact Investigation';
    }
    return 'Monitoring Alert';
  }

  String _formatTime(Object? value) {
    final raw = value?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) {
      return '-';
    }
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }

  String _formatDateLabel(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _historyForDisplay(List<Map<String, dynamic>> alerts) {
    final now = DateTime.now();
    final lastSevenDaysStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    return alerts.where((alert) {
      final timestamp =
          AppRepository.parseTimestamp(alert['timestamp']).toLocal();
      if (_selectedHistoryDate != null) {
        return _isSameDate(timestamp, _selectedHistoryDate!);
      }
      return !timestamp.isBefore(lastSevenDaysStart);
    }).take(7).toList();
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _locationText(Map<String, dynamic>? alert) {
    if (alert == null) {
      return '-';
    }

    final explicit = alert['location']?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final locationName =
        alert['location_name']?.toString() ?? 'Unknown location';
    final roadName = alert['road_name']?.toString();
    final latitude = (alert['latitude'] as num?)?.toDouble();
    final longitude = (alert['longitude'] as num?)?.toDouble();
    final roadPart = roadName == null || roadName.isEmpty ? '' : ' - $roadName';
    final coordinatePart = latitude == null || longitude == null
        ? ''
        : ' (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
    return '$locationName$roadPart$coordinatePart';
  }

  Future<void> _pickHistoryDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedHistoryDate = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystem = MediaQuery.of(context).padding.bottom;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamAlerts(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <Map<String, dynamic>>[];
        final latest = alerts.isNotEmpty ? alerts.first : null;
        final latestLevel = (latest?['impact_level'] as num?)?.toInt() ?? 0;
        final history = _historyForDisplay(alerts);

        return Scaffold(
          backgroundColor: _surface,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppHeader(
                  onSearch: (key) {
                    GlobalSearchHandler.handleSearch(context, key);
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopOverview(latestLevel),
                        const SizedBox(height: 18),
                        _buildImpactClassificationCard(),
                        const SizedBox(height: 18),
                        _buildCurrentAlertCard(latest),
                        const SizedBox(height: 18),
                        _buildManualControlCard(alerts),
                        const SizedBox(height: 18),
                        _buildHistorySection(history),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: buildBottomNav(bottomSystem),
        );
      },
    );
  }

  Widget _buildTopOverview(int latestLevel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EV Impact & Emergency Monitoring',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Automatic impact detection, SOS response, and Firebase incident logging.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetric(
                  'System State',
                  'Armed',
                  'Monitoring Active',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroMetric(
                  'Latest Severity',
                  latestLevel == 0 ? 'Standby' : 'Level $latestLevel',
                  latestLevel == 0
                      ? _statusMessage
                      : _severityTitle(latestLevel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _triggerManualAlert(5),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.sos_rounded),
              label: const Text(
                'SOS EMERGENCY',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactClassificationCard() {
    final levelItems = [
      {'level': 1, 'label': 'Minor vibration'},
      {'level': 2, 'label': 'Light impact'},
      {'level': 3, 'label': 'Significant impact'},
      {'level': 4, 'label': 'Serious accident'},
      {'level': 5, 'label': 'Critical emergency'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Impact Level Classification',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Phone taps and everyday handling should stay in Level 1 or Level 2. Level 3 and above require stronger movement based on the calibrated sensor thresholds.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: levelItems.map((item) {
              final level = item['level'] as int;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _severityColor(level).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Level $level - ${item['label']}',
                  style: TextStyle(
                    color: _severityColor(level),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAlertCard(Map<String, dynamic>? latest) {
    final level = (latest?['impact_level'] as num?)?.toInt() ?? 0;
    final color = _severityColor(level);
    final hasActiveAlert = latest != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasActiveAlert
                      ? color.withValues(alpha: 0.12)
                      : _softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: hasActiveAlert ? color : _primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Current Alert Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _primaryGreen,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasActiveAlert
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasActiveAlert ? 'Level $level' : 'None',
                  style: TextStyle(
                    color: hasActiveAlert ? color : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildStatusRow(
            'Severity',
            latest == null ? 'No active impact' : _severityTitle(level),
          ),
          _buildStatusRow(
            'Vehicle Condition',
            latest?['vehicle_condition']?.toString() ??
                latest?['vehicle_status']?.toString() ??
                'All safety systems normal',
          ),
          _buildStatusRow(
            'Emergency Status',
            latest?['status']?.toString() ?? 'Standby monitoring active',
          ),
          _buildStatusRow('Location', _locationText(latest)),
          _buildStatusRow('Time', _formatTime(latest?['timestamp'])),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualControlCard(List<Map<String, dynamic>> alerts) {
    final controls = [
      {
        'level': 1,
        'label': 'Minor Incident (L1)',
        'icon': Icons.vibration_rounded,
      },
      {
        'level': 2,
        'label': 'Moderate Impact (L2)',
        'icon': Icons.car_repair_rounded,
      },
      {
        'level': 3,
        'label': 'Significant Impact (L3)',
        'icon': Icons.warning_amber_rounded,
      },
      {
        'level': 4,
        'label': 'Serious Accident (L4)',
        'icon': Icons.local_hospital_rounded,
      },
      {
        'level': 5,
        'label': 'Critical Emergency (L5)',
        'icon': Icons.emergency_rounded,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Colors.black12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual Emergency Controls',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use these controls to simulate the same incident flow as the sensor system. Level 4 and Level 5 escalate emergency response automatically.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 16),
          ...controls.map((control) {
            final level = control['level'] as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _triggerManualAlert(level),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _severityColor(level),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(control['icon'] as IconData),
                      const SizedBox(width: 10),
                      Text(
                        control['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory_rounded, color: _primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Automatic accelerometer monitoring is active on this page. Minor taps should stay in low severity, while strong movement is required for serious emergency levels.',
                    style: TextStyle(color: Colors.grey.shade800, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () => _cancelLatestAlert(alerts),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cancel Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List<Map<String, dynamic>> alerts) {
    final subtitle = _selectedHistoryDate == null
        ? 'Showing the latest incident records from the last 7 days.'
        : 'Showing alerts for ${_formatDateLabel(_selectedHistoryDate!)}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Alert History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _primaryGreen,
                ),
              ),
            ),
            if (_selectedHistoryDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedHistoryDate = null;
                  });
                },
                child: const Text(
                  'Last 7 Days',
                  style: TextStyle(color: _primaryGreen),
                ),
              ),
            IconButton(
              onPressed: _pickHistoryDate,
              icon: const Icon(
                Icons.calendar_month_rounded,
                color: _primaryGreen,
              ),
              tooltip: 'Filter by date',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 8),
                  color: Colors.black12,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 38,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                Text(
                  'No incidents found for the selected period.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final level = (alert['impact_level'] as num?)?.toInt() ?? 0;
              final severityColor = _severityColor(level);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      offset: Offset(0, 8),
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: severityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alert['title']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'L$level',
                            style: TextStyle(
                              color: severityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHistoryLine('Alert Type', _alertTypeForLevel(level)),
                    _buildHistoryLine(
                      'Severity',
                      alert['severity']?.toString() ?? _severityTitle(level),
                    ),
                    _buildHistoryLine(
                      'Vehicle Status',
                      alert['vehicle_condition']?.toString() ??
                          alert['vehicle_status']?.toString() ??
                          '-',
                    ),
                    _buildHistoryLine('Location', _locationText(alert)),
                    _buildHistoryLine(
                      'Action Taken',
                      alert['status']?.toString() ?? '-',
                    ),
                    _buildHistoryLine(
                      'Timestamp',
                      _formatTime(alert['timestamp']),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHistoryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomNav(double bottomSystem) {
    return Container(
      height: 85 + bottomSystem,
      padding: EdgeInsets.only(top: 8, bottom: bottomSystem + 8),
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
        if (index == 2) {
          return;
        }

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverHomePage()),
          );
        }

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChargePage()),
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
      child: Container(
        width: 70,
        decoration: isActive
            ? BoxDecoration(
                color: _primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: isActive ? _primaryGreen : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? _primaryGreen : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
