import 'dart:async';
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
  static const Color _surface = Color(0xFFF3F4F6);

  int selectedTab = 2;
  String _statusMessage = 'Monitoring active';
  bool _showingImpactDialog = false;
  bool _accidentDetectionEnabled = true;
  late final ImpactDetectionService _impactService;

  @override
  void initState() {
    super.initState();
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    if (_accidentDetectionEnabled) {
      _impactService.start();
    }
  }

  @override
  void dispose() {
    _impactService.stop();
    super.dispose();
  }

  void _handleImpactDetected(ImpactEvent event) {
    if (!mounted || _showingImpactDialog || !_accidentDetectionEnabled) {
      return;
    }

    setState(() {
      _statusMessage =
          'Impact detected (${event.magnitude.toStringAsFixed(1)} m/s^2)';
    });

    _showEmergencyCountdown(
      title: 'Potential accident detected. Cancel if safe.',
      subtitle:
          '${AppRepository.severityLabel(event.level)} detected from the phone accelerometer. ${event.description}',
      impactLevel: event.level,
      source: 'accelerometer',
      manualTrigger: false,
      autoDispatch: event.level >= 4,
      accelerationMagnitude: event.magnitude,
      detectedAt: event.detectedAt,
    );
  }

  Future<void> _createCountdownAlert({
    required int impactLevel,
    required String source,
    required bool manualTrigger,
    required bool emergencyTriggered,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    final position = await _resolvePosition();
    final latitude = position?.latitude ?? 3.1390;
    final longitude = position?.longitude ?? 101.6869;

    final alert = manualTrigger
        ? await AppRepository.sendManualAlert(
            impactLevel: impactLevel,
            vehicleStatus: _vehicleConditionForLevel(impactLevel),
            latitude: latitude,
            longitude: longitude,
            emergencyTriggered: emergencyTriggered,
            sourceDetail: source,
            title: 'Manual alert triggered',
            accidentStatus: _emergencyStatusForLevel(impactLevel),
            accelerationMagnitude: accelerationMagnitude,
            timestamp: detectedAt,
            extraData: {
              'gps_location':
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              'impact_detected_by': 'Alert control panel',
              'severity_label': _severityTitle(impactLevel),
            },
          )
        : await AppRepository.sendAutomaticAlert(
            impactLevel: impactLevel,
            vehicleStatus: _vehicleConditionForLevel(impactLevel),
            latitude: latitude,
            longitude: longitude,
            emergencyTriggered: emergencyTriggered,
            sourceDetail: source,
            title: 'Potential accident detected',
            accidentStatus: _emergencyStatusForLevel(impactLevel),
            accelerationMagnitude: accelerationMagnitude,
            timestamp: detectedAt,
            extraData: {
              'gps_location':
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              'impact_detected_by': 'Phone accelerometer IoT simulation',
              'severity_label': _severityTitle(impactLevel),
            },
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = emergencyTriggered
          ? 'Emergency dispatch sent'
          : 'Impact logged successfully';
    });

    _showImpactSyncResult(
      emergencyTriggered,
      alert['impact_label']?.toString() ?? _severityTitle(impactLevel),
    );
  }

  Future<void> _showEmergencyCountdown({
    required String title,
    required String subtitle,
    required int impactLevel,
    required String source,
    required bool manualTrigger,
    required bool autoDispatch,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    if (_showingImpactDialog) {
      return;
    }

    _showingImpactDialog = true;
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
                await _createCountdownAlert(
                  impactLevel: impactLevel,
                  source: source,
                  manualTrigger: manualTrigger,
                  emergencyTriggered: autoDispatch,
                  accelerationMagnitude: accelerationMagnitude,
                  detectedAt: detectedAt,
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
    _showingImpactDialog = false;
    if (cancelled && mounted) {
      setState(() {
        _statusMessage = 'Monitoring active';
      });
    }
  }

  void _showImpactSyncResult(bool emergencyTriggered, String severityLabel) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(emergencyTriggered ? 'Help is on the way' : 'Alert logged'),
        content: Text(
          emergencyTriggered
              ? '$severityLabel was sent to Firebase and synced to the ambulance dashboard, notification page, and insurance analytics.'
              : '$severityLabel was stored in Firebase and added to the alert history, insurance feed, and notification page.',
        ),
        actions: [
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
      ),
    );
  }

  Future<void> _triggerAlert(
    int level, {
    required String source,
    required String title,
    double? accelerationMagnitude,
    DateTime? detectedAt,
    String? vehicleStatusOverride,
    Map<String, dynamic>? extraData,
    bool showPostAlertDialog = true,
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

    await AppRepository.sendManualAlert(
      impactLevel: level,
      vehicleStatus: vehicleCondition,
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: level >= 4,
      sourceDetail: source,
      title: title,
      accidentStatus: emergencyStatus,
      accelerationMagnitude: accelerationMagnitude,
      timestamp: timestamp,
      extraData: {
        'vehicle_condition': vehicleCondition,
        'location': locationLabel,
        'severity_label': _severityTitle(level),
        ...?extraData,
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = _statusMessageForLevel(level);
    });

    if (showPostAlertDialog) {
      await showImpactAlert(
        level,
        locationLabel: locationLabel,
        emergencyStatus: emergencyStatus,
        vehicleCondition: vehicleCondition,
        detectedAt: timestamp,
      );
    }
  }

  void _toggleAccidentDetection(bool enabled) {
    setState(() {
      _accidentDetectionEnabled = enabled;
      _statusMessage = enabled
          ? 'Accident detection armed and monitoring'
          : 'Accident detection paused';
    });

    if (enabled) {
      _impactService.start();
    } else {
      _impactService.stop();
    }
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

  // Shared popup flow for automatic impact detection and manual emergency
  // controls. This restores the missing showDialog behavior for impact events.
  Future<void> showImpactAlert(
    int level, {
    required String locationLabel,
    required String emergencyStatus,
    required String vehicleCondition,
    required DateTime detectedAt,
  }) async {
    if (!mounted || _showingImpactDialog) return;

    _showingImpactDialog = true;

    int countdown = 10;
    Timer? timer;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
                if (countdown <= 1) {
                  t.cancel();
                  Navigator.of(dialogContext).pop();
                  return;
                }

                dialogSetState(() {
                  countdown--;
                });
              });

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Title
                      const Text(
                        'Potential accident detected\nConfirm if you are safe.',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 14),

                      /// Level description
                      Text(
                        _severityTitle(level),
                        style: TextStyle(
                          fontSize: 16,
                          color: _severityColor(level),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _popupMessage(level),
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),

                      const SizedBox(height: 20),

                      /// Countdown text
                      Text(
                        'This alert will be saved in $countdown seconds.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 10),

                      /// Progress bar
                      LinearProgressIndicator(
                        value: (10 - countdown) / 10,
                        color: _primaryGreen,
                        backgroundColor: Colors.grey.shade300,
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'This simulates vehicle IoT impact sensors using the phone accelerometer.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),

                      const SizedBox(height: 30),

                      /// Cancel button
                      Row(
                        children: [
                          /// I'M OK
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                timer?.cancel();
                                Navigator.of(dialogContext).pop();

                                setState(() {
                                  _statusMessage = "Driver confirmed safe";
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primaryGreen,
                                side: const BorderSide(color: _primaryGreen),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "I'm OK",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          /// SEND HELP
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                timer?.cancel();
                                Navigator.of(dialogContext).pop();

                                _showHelpComingDialog();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Send Help",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      timer?.cancel();
      _showingImpactDialog = false;
    }
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

  Future<void> _handleControlPanelPress(int level) async {
    if (!_accidentDetectionEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Arm accident detection to use the alert control hub.',
            ),
          ),
        );
      }
      return;
    }

    if (level <= 3) {
      await _showGuidedReportDialog(level);
      return;
    }

    await _showEmergencyControlCountdown(level);
  }

  Future<void> _sendManualEmergencyAlert(int level) async {
    await _triggerAlert(
      level,
      source: 'manual_emergency_level_$level',
      title: level == 5
          ? 'Level 5 SOS emergency requested'
          : 'Level 4 emergency assistance requested',
      accelerationMagnitude: _manualImpactMagnitudeForLevel(level),
      detectedAt: DateTime.now(),
      extraData: {
        'incident_category': 'emergency_case',
        'dashboard_rank': 'emergency',
        'response_priority': level == 5 ? 'critical' : 'high',
        'driver_response_summary': level == 5
            ? 'SOS pressed by driver. Immediate ambulance response requested.'
            : 'Level 4 assistance requested by driver. Ambulance review needed.',
        'responder_note': level == 5
            ? 'Treat as the highest-priority case in ambulance and insurance feeds.'
            : 'Display near the top of the ambulance emergency queue for fast review.',
      },
      showPostAlertDialog: false,
    );
  }

  Future<void> _showEmergencyControlCountdown(int level) async {
    int seconds = 5;
    bool shouldSend = false;
    bool cancelled = false;
    Timer? timer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (value) {
              if (seconds == 0) {
                shouldSend = true;
                value.cancel();
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                return;
              }

              seconds -= 1;
              if (context.mounted) {
                dialogSetState(() {});
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        level == 5
                            ? Icons.sos_rounded
                            : Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      level == 5 ? 'Level 5 SOS' : 'Level 4 Emergency',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      level == 5
                          ? 'Emergency alert will be sent automatically unless this is a false alarm.'
                          : 'Emergency assistance request will be sent automatically unless this is a false alarm.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(
                      value: seconds / 5,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.red,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sending in $seconds second${seconds == 1 ? '' : 's'}...',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              shouldSend = true;
                              timer?.cancel();
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              cancelled = true;
                              timer?.cancel();
                              Navigator.of(dialogContext).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    timer?.cancel();

    if (cancelled || !shouldSend) {
      if (cancelled && mounted) {
        setState(() {
          _statusMessage = 'Emergency alert cancelled before sending';
        });
      }
      return;
    }

    await _sendManualEmergencyAlert(level);
    if (!mounted) {
      return;
    }
    await _showEmergencySentDialog(level);
  }

  Future<void> _showEmergencySentDialog(int level) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  level == 5 ? 'SOS sent' : 'Emergency sent',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  level == 5
                      ? 'Critical alert data has been sent to the alert log and notification feeds.'
                      : 'Emergency assistance data has been sent to the alert log and notification feeds.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showGuidedReportDialog(int level) async {
    final questions = _questionsForLevel(level);
    final answers = List<bool?>.filled(questions.length, null);
    var additionalComments = '';
    var showValidation = false;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 470,
                  maxHeight: 720,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
                        decoration: const BoxDecoration(
                          color: _primaryGreen,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notify',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _severityTitle(level),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _questionnaireIntro(level),
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            for (
                              var index = 0;
                              index < questions.length;
                              index++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      questions[index].prompt,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDialogChoiceButton(
                                            label: questions[index].yesLabel,
                                            selected: answers[index] == true,
                                            onTap: () {
                                              dialogSetState(() {
                                                answers[index] = true;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildDialogChoiceButton(
                                            label: questions[index].noLabel,
                                            selected: answers[index] == false,
                                            onTap: () {
                                              dialogSetState(() {
                                                answers[index] = false;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              'Additional comments for ambulance, technician, or support team',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              minLines: 3,
                              maxLines: 4,
                              textInputAction: TextInputAction.done,
                              onChanged: (value) {
                                additionalComments = value.trim();
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Add anything important responders should know here.',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
                                filled: true,
                                fillColor: _primaryGreen.withValues(
                                  alpha: 0.04,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: _primaryGreen.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: _primaryGreen.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(18),
                                  ),
                                  borderSide: BorderSide(
                                    color: _primaryGreen,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (showValidation)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Text(
                                  'Please answer all questions before continuing.',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Center(
                              child: SizedBox(
                                width: 170,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (answers.any(
                                      (answer) => answer == null,
                                    )) {
                                      dialogSetState(() {
                                        showValidation = true;
                                      });
                                      return;
                                    }
                                    FocusScope.of(dialogContext).unfocus();
                                    Navigator.of(dialogContext).pop(true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Enter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (submitted != true || answers.any((answer) => answer == null)) {
      return;
    }

    await _submitGuidedReport(
      level,
      questions,
      answers.map((answer) => answer ?? false).toList(),
      additionalComments,
    );
  }

  Future<void> _submitGuidedReport(
    int level,
    List<_AlertQuestionItem> questions,
    List<bool> answers,
    String additionalComments,
  ) async {
    await _triggerAlert(
      level,
      source: 'guided_report_level_$level',
      title: 'Level $level driver report submitted',
      accelerationMagnitude: _manualImpactMagnitudeForLevel(level),
      detectedAt: DateTime.now(),
      vehicleStatusOverride: _guidedVehicleStatus(level, answers),
      extraData: {
        'incident_category': 'guided_report',
        'dashboard_rank': 'monitoring',
        'response_priority': level == 3 ? 'priority_review' : 'routine_review',
        'driver_response_summary': _questionnaireSummary(level, answers),
        'responder_note': _responderNote(level, answers),
        ..._questionnairePayload(
          questions,
          answers,
          additionalComments: additionalComments,
        ),
      },
      showPostAlertDialog: false,
    );

    if (!mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _showGuidedReportSuccessDialog(level);
  }

  Future<void> _showGuidedReportSuccessDialog(int level) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: _primaryGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _primaryGreen,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Submitted',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Level $level details are now available in the technician and ambulance dashboards for follow-up.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _questionnaireIntro(int level) {
    switch (level) {
      case 1:
        return 'Please answer a few quick safety questions before sending your Level 1 minor report.';
      case 2:
        return 'Tell us what happened so the support team can review your Level 2 impact properly.';
      default:
        return 'Complete this short check-in so the team can review your Level 3 case quickly.';
    }
  }

  List<_AlertQuestionItem> _questionsForLevel(int level) {
    switch (level) {
      case 1:
        return const [
          _AlertQuestionItem(prompt: 'Is everyone inside the vehicle safe?'),
          _AlertQuestionItem(
            prompt: 'Can the vehicle continue driving normally?',
          ),
          _AlertQuestionItem(
            prompt: 'Do you see any minor exterior scratches or tire issues?',
          ),
        ];
      case 2:
        return const [
          _AlertQuestionItem(
            prompt: 'Did the collision cause visible vehicle damage?',
          ),
          _AlertQuestionItem(
            prompt: 'Do you need technician support at your location?',
            yesLabel: 'Need help',
            noLabel: 'No help',
          ),
          _AlertQuestionItem(
            prompt: 'Is the battery or charging area showing a warning sign?',
          ),
        ];
      default:
        return const [
          _AlertQuestionItem(
            prompt: 'Is anyone feeling pain or dizziness after the impact?',
          ),
          _AlertQuestionItem(
            prompt: 'Do you smell smoke or feel unusual battery heat?',
          ),
          _AlertQuestionItem(
            prompt: 'Should the response team contact you immediately?',
            yesLabel: 'Contact me',
            noLabel: 'Not now',
          ),
        ];
    }
  }

  Widget _buildDialogChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? _primaryGreen : Colors.white,
        foregroundColor: selected ? Colors.white : _primaryGreen,
        side: const BorderSide(color: _primaryGreen),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  String _guidedVehicleStatus(int level, List<bool> answers) {
    final positiveAnswers = answers.where((answer) => answer).length;
    switch (level) {
      case 1:
        return positiveAnswers >= 2
            ? 'Minor incident reported with follow-up checks requested by the driver.'
            : 'Minor incident reported. Driver is stable and continuing with monitoring.';
      case 2:
        return positiveAnswers >= 2
            ? 'Level 2 impact reported. Technician review is recommended before the next trip.'
            : 'Level 2 impact reported. Driver can wait for a standard follow-up review.';
      default:
        return positiveAnswers >= 2
            ? 'Level 3 report indicates urgent driver and vehicle follow-up is needed.'
            : 'Level 3 report logged with stable answers, but manual review is still recommended.';
    }
  }

  String _questionnaireSummary(int level, List<bool> answers) {
    final positiveAnswers = answers.where((answer) => answer).length;
    if (level == 1) {
      return positiveAnswers == 0
          ? 'Driver reports a small issue and no extra support is needed.'
          : 'Driver reported a minor issue and requested some follow-up attention.';
    }
    if (level == 2) {
      return positiveAnswers <= 1
          ? 'Driver reports a manageable impact with limited visible issues.'
          : 'Driver reports a noticeable impact and technician follow-up should be reviewed.';
    }
    return positiveAnswers <= 1
        ? 'Driver reports a moderate incident with stable answers so far.'
        : 'Driver reports a moderate incident with urgent follow-up indicators.';
  }

  String _responderNote(int level, List<bool> answers) {
    final positiveAnswers = answers.where((answer) => answer).length;
    if (level == 3 && positiveAnswers >= 2) {
      return 'Keep this case near the top of the monitoring feed and contact the driver soon.';
    }
    if (level == 2 && positiveAnswers >= 2) {
      return 'Technician review should happen before the vehicle continues a long trip.';
    }
    return 'Feed card can stay in the standard monitoring queue unless the driver sends more updates.';
  }

  Map<String, dynamic> _questionnairePayload(
    List<_AlertQuestionItem> questions,
    List<bool> answers, {
    String additionalComments = '',
  }) {
    final payload = <String, dynamic>{};
    for (var index = 0; index < questions.length; index++) {
      payload['question_${index + 1}'] = questions[index].prompt;
      payload['answer_${index + 1}'] = answers[index]
          ? questions[index].yesLabel
          : questions[index].noLabel;
    }
    if (additionalComments.isNotEmpty) {
      payload['additional_comments'] = additionalComments;
      payload['responder_comments'] = additionalComments;
    }
    return payload;
  }

  double _manualImpactMagnitudeForLevel(int level) {
    switch (level) {
      case 1:
        return 18;
      case 2:
        return 48;
      case 3:
        return 78;
      case 4:
        return 94;
      case 5:
        return 108;
      default:
        return 0;
    }
  }

  Future<void> _showHelpComingDialog({int level = 5}) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_hospital, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  level == 5 ? 'Level 5 SOS sent' : 'Level 4 emergency sent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  level == 5
                      ? 'All details have been sent to nearby ambulance drivers and technicians. This case will appear at the top of their emergency dashboards.'
                      : 'All details have been sent to nearby ambulance drivers and technicians so they can review the emergency case immediately.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystem = MediaQuery.of(context).padding.bottom;

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopOverview(),
                    const SizedBox(height: 18),
                    Expanded(child: _buildImpactClassificationCard()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomNav(bottomSystem),
    );
  }

  Widget _buildTopOverview() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E6B37), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.car_crash_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accident Detection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: _accidentDetectionEnabled,
                activeThumbColor: _primaryGreen,
                activeTrackColor: Colors.white,
                inactiveThumbColor: Colors.grey.shade200,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.4),
                onChanged: _toggleAccidentDetection,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelNode({
    required int level,
    required String title,
    required String subtitle,
    required bool enabled,
    required bool isTopRow,
    required bool isLeftColumn,
    required double width,
    required double height,
  }) {
    final accent = _severityColor(level);
    final contentAlignment = Alignment(
      isLeftColumn ? -0.78 : 0.78,
      isTopRow ? -0.74 : 0.74,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _handleControlPanelPress(level) : null,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: width,
          height: height,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.1)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.22)
                  : Colors.grey.shade300,
            ),
          ),
          child: Align(
            alignment: contentAlignment,
            child: SizedBox(
              width: width * 0.54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    level >= 4
                        ? Icons.warning_amber_rounded
                        : Icons.health_and_safety_outlined,
                    color: enabled ? accent : Colors.grey.shade500,
                    size: 29,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? accent : Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? Colors.grey.shade700
                          : Colors.grey.shade500,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImpactClassificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
            'Alert Control Hub',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
            ),
          ),

          const SizedBox(height: 6),
          Text(
            _accidentDetectionEnabled
                ? 'Manual controls are active while accident detection is armed.'
                : 'Arm accident detection to enable the emergency control buttons.',
            style: TextStyle(
              color: _accidentDetectionEnabled
                  ? Colors.grey.shade700
                  : Colors.red.shade700,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const nodeGap = 14.0;
                final hubWidth = constraints.maxWidth < 374
                    ? constraints.maxWidth
                    : 374.0;
                final hubHeight = constraints.maxHeight < 372
                    ? constraints.maxHeight
                    : 372.0;
                final nodeWidth = (hubWidth - nodeGap) / 2;
                final nodeHeight = (hubHeight - nodeGap) / 2;
                final centerSize = hubWidth < 350 ? 146.0 : 156.0;

                return Center(
                  child: SizedBox(
                    width: hubWidth,
                    height: hubHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _buildLevelNode(
                            level: 1,
                            title: 'Level 1',
                            subtitle: 'Minor',
                            enabled: _accidentDetectionEnabled,
                            isTopRow: true,
                            isLeftColumn: true,
                            width: nodeWidth,
                            height: nodeHeight,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _buildLevelNode(
                            level: 2,
                            title: 'Level 2',
                            subtitle: 'Moderate',
                            enabled: _accidentDetectionEnabled,
                            isTopRow: true,
                            isLeftColumn: false,
                            width: nodeWidth,
                            height: nodeHeight,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: _buildLevelNode(
                            level: 3,
                            title: 'Level 3',
                            subtitle: 'Serious',
                            enabled: _accidentDetectionEnabled,
                            isTopRow: false,
                            isLeftColumn: true,
                            width: nodeWidth,
                            height: nodeHeight,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _buildLevelNode(
                            level: 4,
                            title: 'Level 4',
                            subtitle: 'Emergency',
                            enabled: _accidentDetectionEnabled,
                            isTopRow: false,
                            isLeftColumn: false,
                            width: nodeWidth,
                            height: nodeHeight,
                          ),
                        ),
                        Opacity(
                          opacity: _accidentDetectionEnabled ? 1 : 0.55,
                          child: Container(
                            width: centerSize,
                            height: centerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade700,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.28),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _accidentDetectionEnabled
                                    ? () => _handleControlPanelPress(5)
                                    : null,
                                child: const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sos_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Level 5',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'SOS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomNav(double bottomSystem) {
    return Container(
      height: 88 + bottomSystem,
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

class _AlertQuestionItem {
  const _AlertQuestionItem({
    required this.prompt,
    this.yesLabel = 'Yes',
    this.noLabel = 'No',
  });

  final String prompt;
  final String yesLabel;
  final String noLabel;
}
