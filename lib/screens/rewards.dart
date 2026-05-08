import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_repository.dart';
import '../services/impact_detection_service.dart';
import 'alert.dart';
import 'app_footer.dart';
import 'app_header.dart';
import 'charge.dart';
import 'global_search.dart';
import 'home_driver.dart';
import 'noti.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  static const Color _brandColor = Color(0xFF2E7D32);
  static const Color _brandLight = Color(0xFF66BB6A);
  static const Color _pageBackground = Color(0xFFF7F7F4);

  late final ImpactDetectionService _impactService;
  bool _isImpactDialogVisible = false;
  double _currentLatitude = 3.1390;
  double _currentLongitude = 101.6869;

  bool _isLoadingRewards = true;
  int totalDistanceKm = 1240;
  int chargingSessions = 48;
  int ecoDrivingScore = 92;
  late int totalPoints;
  int studentsHelped = 3;
  int carbonSavedKg = 5;
  int waterSavedLitres = 31;
  int _checkInStreak = 0;
  String? _lastCheckInDate;
  String? _reminderSentDate;
  bool _checkedInToday = false;
  int _todayCheckInPoints = 1;
  int _safeDrivingDays = 0;
  int _ecoChallengeDays = 2;
  int _offPeakCharges = 3;
  int _fullChargeSessions = 2;
  bool _safeDrivingAwarded = false;
  bool _ecoChallengeAwarded = false;
  bool _offPeakAwarded = false;
  bool _fullChargeAwarded = false;
  late final List<Map<String, dynamic>> _donationCauses;

  @override
  void initState() {
    super.initState();
    totalPoints = (totalDistanceKm * 10) + 420 + 260;
    _donationCauses = [
      {
        'title': "Children's Education Fund",
        'icon': Icons.school_rounded,
        'recommendedPoints': 1000,
        'progress': 0.72,
        'impact': 'You helped 3 students',
      },
      {
        'title': 'Cancer Patient Support',
        'icon': Icons.favorite_rounded,
        'recommendedPoints': 800,
        'progress': 0.58,
        'impact': '18 care packs funded',
      },
      {
        'title': 'Mental Health Support',
        'icon': Icons.self_improvement_rounded,
        'recommendedPoints': 600,
        'progress': 0.49,
        'impact': '6 counselling hours unlocked',
      },
    ];
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    _impactService.start();
    _loadLocation();
    unawaited(_initializeRewards());
  }

  @override
  void dispose() {
    _impactService.stop();
    super.dispose();
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
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
    } catch (_) {}
  }

  Future<void> _initializeRewards() async {
    try {
      await _seedDemoRewardNotificationsIfNeeded();
      final rewards = await AppRepository.getCurrentUserRewards();
      final alerts = await AppRepository.getCurrentUserAlerts();

      final stats = _asMap(rewards['stats']);
      final checkIn = _asMap(rewards['checkIn']);
      final missions = _asMap(rewards['missions']);
      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

      var streak = _asInt(checkIn['streak']) ?? 0;
      final lastCheckInDate = checkIn['lastCheckInDate']?.toString();
      final reminderSentDate = checkIn['reminderSentDate']?.toString();
      final missedDay =
          lastCheckInDate != null &&
          lastCheckInDate != todayKey &&
          lastCheckInDate != yesterdayKey;
      if (missedDay) {
        streak = 0;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        totalDistanceKm = _asInt(stats['distance']) ?? totalDistanceKm;
        chargingSessions =
            _asInt(stats['chargingSessions']) ?? chargingSessions;
        ecoDrivingScore = _asInt(stats['ecoScore']) ?? ecoDrivingScore;
        totalPoints = _asInt(rewards['points']) ?? totalPoints;
        studentsHelped = _asInt(stats['studentsHelped']) ?? studentsHelped;
        carbonSavedKg = _asInt(stats['carbonSavedKg']) ?? carbonSavedKg;
        waterSavedLitres =
            _asInt(stats['waterSavedLitres']) ?? waterSavedLitres;
        _checkInStreak = streak;
        _lastCheckInDate = lastCheckInDate;
        _reminderSentDate = reminderSentDate;
        _checkedInToday = lastCheckInDate == todayKey;
        _todayCheckInPoints = _pointsForCheckInDay(
          _checkedInToday ? streak : streak + 1,
        );
        _safeDrivingDays = _calculateSafeDrivingDays(alerts, now);
        _ecoChallengeDays = _clampInt(
          _asInt(missions['ecoChallengeDays']) ??
              _defaultEcoChallengeDays(ecoDrivingScore),
          0,
          3,
        );
        _offPeakCharges = _clampInt(
          _asInt(missions['offPeakCharges']) ?? chargingSessions,
          0,
          4,
        );
        _fullChargeSessions = _clampInt(
          _asInt(missions['fullChargeSessions']) ?? (chargingSessions ~/ 16),
          0,
          3,
        );
        _safeDrivingAwarded = missions['safeDrivingAwarded'] == true;
        _ecoChallengeAwarded = missions['ecoChallengeAwarded'] == true;
        _offPeakAwarded = missions['offPeakAwarded'] == true;
        _fullChargeAwarded = missions['fullChargeAwarded'] == true;
        _isLoadingRewards = false;
      });

      await AppRepository.upsertCurrentUserRewards(
        points: totalPoints,
        checkIn: {
          'lastCheckInDate': _lastCheckInDate,
          'streak': _checkInStreak,
          'reminderSentDate': _reminderSentDate,
        },
        missions: {
          'safeDrivingDays': _safeDrivingDays,
          'ecoChallengeDays': _ecoChallengeDays,
          'offPeakCharges': _offPeakCharges,
          'fullChargeSessions': _fullChargeSessions,
          'safeDrivingAwarded': _safeDrivingAwarded,
          'ecoChallengeAwarded': _ecoChallengeAwarded,
          'offPeakAwarded': _offPeakAwarded,
          'fullChargeAwarded': _fullChargeAwarded,
        },
        stats: {
          'distance': totalDistanceKm,
          'chargingSessions': chargingSessions,
          'ecoScore': ecoDrivingScore,
          'studentsHelped': studentsHelped,
          'carbonSavedKg': carbonSavedKg,
          'waterSavedLitres': waterSavedLitres,
        },
      );

      await _syncMissionAwards();
      await AppRepository.queueDailyCheckInReminderIfNeeded(
        now: now,
        lastCheckInDate: _lastCheckInDate,
        reminderSentDate: _reminderSentDate,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _safeDrivingDays = 5;
        _ecoChallengeDays = _defaultEcoChallengeDays(ecoDrivingScore);
        _offPeakCharges = 3;
        _fullChargeSessions = 2;
        _isLoadingRewards = false;
      });
    }
  }

  Future<void> _seedDemoRewardNotificationsIfNeeded() async {
    final existingRewards = await AppRepository.getCurrentUserNotifications(
      type: 'Rewards',
    );
    if (existingRewards.any((item) => item['points_delta'] != null)) {
      return;
    }

    final now = DateTime.now();
    await AppRepository.logRewardNotification(
      title: 'Eco Driving Reward',
      message: 'Maintained strong eco driving performance this week.',
      pointsDelta: 640,
      rewardKind: 'eco_reward',
      timestamp: now.subtract(const Duration(hours: 2)),
    );
    await AppRepository.logRewardNotification(
      title: 'Smart Charging Bonus',
      message: 'Off-peak charging sessions added bonus points.',
      pointsDelta: 180,
      rewardKind: 'smart_charging',
      timestamp: now.subtract(const Duration(days: 1, hours: 1)),
    );
    await AppRepository.logRewardNotification(
      title: 'Daily Driving Reward',
      message: 'Daily EV driving consistency earned extra points.',
      pointsDelta: 150,
      rewardKind: 'daily_driving',
      timestamp: now.subtract(const Duration(days: 2, hours: 3)),
    );
  }

  Future<void> _handleCheckIn() async {
    if (_checkedInToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily check-in already completed today.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));
    final nextStreak = _lastCheckInDate == yesterdayKey
        ? _checkInStreak + 1
        : 1;
    final earnedPoints = _pointsForCheckInDay(nextStreak);

    setState(() {
      _checkInStreak = nextStreak;
      _lastCheckInDate = todayKey;
      _reminderSentDate = todayKey;
      _checkedInToday = true;
      _todayCheckInPoints = earnedPoints;
      totalPoints += earnedPoints;
      if (ecoDrivingScore >= 90) {
        _ecoChallengeDays = _clampInt(_ecoChallengeDays + 1, 0, 3);
      } else {
        _ecoChallengeDays = 0;
      }
    });

    await AppRepository.upsertCurrentUserRewards(
      points: totalPoints,
      checkIn: {
        'lastCheckInDate': todayKey,
        'streak': _checkInStreak,
        'reminderSentDate': todayKey,
      },
      missions: {'ecoChallengeDays': _ecoChallengeDays},
    );
    await AppRepository.logRewardNotification(
      title: 'Daily Check-In Reward',
      message:
          'Streak updated to $_checkInStreak day${_checkInStreak == 1 ? '' : 's'}.',
      pointsDelta: earnedPoints,
      rewardKind: 'daily_check_in',
      timestamp: now,
    );

    await _syncMissionAwards(showSnackBar: true);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Check-in complete. +$earnedPoints points added.'),
      ),
    );
  }

  Future<void> _syncMissionAwards({bool showSnackBar = false}) async {
    var earned = 0;
    final missionUpdates = <String, dynamic>{};
    final now = DateTime.now();
    final rewardNotifications = <Future<void>>[];

    void addMission({
      required String title,
      required int points,
      required String key,
    }) {
      earned += points;
      missionUpdates[key] = true;
      rewardNotifications.add(
        AppRepository.logRewardNotification(
          title: title,
          message: '$title unlocked and added to your rewards progress.',
          pointsDelta: points,
          rewardKind: key,
          timestamp: now,
        ),
      );
    }

    if (_safeDrivingDays >= 7 && !_safeDrivingAwarded) {
      _safeDrivingAwarded = true;
      addMission(
        title: 'Safe Driving Bonus',
        points: 300,
        key: 'safeDrivingAwarded',
      );
    }
    if (_ecoChallengeDays >= 3 && !_ecoChallengeAwarded) {
      _ecoChallengeAwarded = true;
      addMission(
        title: 'Eco Challenge Bonus',
        points: 150,
        key: 'ecoChallengeAwarded',
      );
    }
    if (_offPeakCharges >= 4 && !_offPeakAwarded) {
      _offPeakAwarded = true;
      addMission(
        title: 'Off-Peak Charging Bonus',
        points: 50,
        key: 'offPeakAwarded',
      );
    }
    if (_fullChargeSessions >= 3 && !_fullChargeAwarded) {
      _fullChargeAwarded = true;
      addMission(
        title: 'Full Charge Bonus',
        points: 20,
        key: 'fullChargeAwarded',
      );
    }

    if (earned == 0) {
      return;
    }

    setState(() {
      totalPoints += earned;
    });

    await AppRepository.upsertCurrentUserRewards(
      points: totalPoints,
      missions: missionUpdates,
    );
    await Future.wait(rewardNotifications);

    if (!mounted || !showSnackBar) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mission completed. +$earned points added.')),
    );
  }

  int _calculateSafeDrivingDays(
    List<Map<String, dynamic>> alerts,
    DateTime now,
  ) {
    final alertDays = alerts
        .map(
          (alert) => _dateKey(AppRepository.parseTimestamp(alert['timestamp'])),
        )
        .toSet();
    var streak = 0;
    for (var day = 0; day < 7; day++) {
      final dayKey = _dateKey(now.subtract(Duration(days: day)));
      if (alertDays.contains(dayKey)) {
        break;
      }
      streak += 1;
    }
    return streak;
  }

  int _defaultEcoChallengeDays(int score) {
    if (score >= 95) {
      return 3;
    }
    if (score >= 90) {
      return 2;
    }
    if (score >= 85) {
      return 1;
    }
    return 0;
  }

  int _checkInCycleDay(int streak) {
    if (streak <= 0) {
      return 1;
    }
    final remainder = streak % 7;
    return remainder == 0 ? 7 : remainder;
  }

  int _pointsForCheckInDay(int streak) {
    final day = _checkInCycleDay(streak);
    if (day <= 5) {
      return 1;
    }
    if (day == 6) {
      return 2;
    }
    return 5;
  }

  int get _visibleStreakProgress {
    if (_checkInStreak <= 0) {
      return 0;
    }
    final remainder = _checkInStreak % 7;
    return remainder == 0 ? 7 : remainder;
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  int _clampInt(int value, int min, int max) {
    return value.clamp(min, max).toInt();
  }

  void _handleImpactDetected(ImpactEvent event) {
    if (!mounted || _isImpactDialogVisible) {
      return;
    }

    _showEmergencyCountdown(
      title: 'Potential accident detected. Cancel if safe.',
      subtitle:
          '${AppRepository.severityLabel(event.level)} detected from the phone accelerometer. ${event.description}',
      impactLevel: event.level,
      source: 'accelerometer',
      autoDispatch: event.level >= 4,
      accelerationMagnitude: event.magnitude,
      detectedAt: event.detectedAt,
    );
  }

  Future<void> _createAlert({
    required int impactLevel,
    required String source,
    required bool emergencyTriggered,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    await _loadLocation();

    final alert = await AppRepository.sendAutomaticAlert(
      impactLevel: impactLevel,
      vehicleStatus: _vehicleStatusForLevel(impactLevel),
      latitude: _currentLatitude,
      longitude: _currentLongitude,
      emergencyTriggered: emergencyTriggered,
      sourceDetail: source,
      title: 'Potential accident detected',
      accidentStatus: emergencyTriggered
          ? 'Emergency dispatch initiated'
          : 'Impact logged for monitoring',
      accelerationMagnitude: accelerationMagnitude,
      timestamp: detectedAt,
      extraData: {
        'gps_location':
            '${_currentLatitude.toStringAsFixed(5)}, ${_currentLongitude.toStringAsFixed(5)}',
        'impact_detected_by': 'Phone accelerometer IoT simulation',
      },
    );

    if (!mounted) {
      return;
    }

    _showHelpOnTheWay(
      emergencyTriggered,
      alert['impact_label']?.toString() ??
          AppRepository.severityLabel(impactLevel),
    );
  }

  Future<void> _showEmergencyCountdown({
    required String title,
    required String subtitle,
    required int impactLevel,
    required String source,
    required bool autoDispatch,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    if (_isImpactDialogVisible) {
      return;
    }

    _isImpactDialogVisible = true;
    int seconds = 5;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency flow cancelled by driver')),
      );
    }
  }

  void _showHelpOnTheWay(bool emergencyTriggered, String severityLabel) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(emergencyTriggered ? 'Help is on the way' : 'Alert logged'),
        content: Text(
          emergencyTriggered
              ? '$severityLabel was sent to Firebase, the hospital emergency dashboard, the notification page, and insurance analytics.'
              : '$severityLabel was stored in Firebase and added to the alert history and notification page.',
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
      backgroundColor: _pageBackground,
      body: Column(
        children: [
          AppHeader(
            onSearch: (key) {
              GlobalSearchHandler.handleSearch(context, key);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPointsCard(),
                  const SizedBox(height: 18),
                  _buildCheckInCard(),
                  const SizedBox(height: 18),
                  _buildStatsSection(),
                  const SizedBox(height: 20),
                  _buildMissionSection(),
                  const SizedBox(height: 20),
                  _buildDonationSection(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppFooter(
        currentIndex: 4,
        onTap: _handleFooterTap,
        activeColor: _brandColor,
      ),
    );
  }

  void _handleFooterTap(int index) {
    if (index == 4) {
      return;
    }

    final page = switch (index) {
      0 => const DriverHomePage(),
      1 => const ChargePage(),
      2 => const AlertPage(),
      3 => const NotificationPage(),
      _ => null,
    };

    if (page == null) {
      return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandColor, _brandLight],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E7D32),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rewards Dashboard',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Points Earned: $totalPoints',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1 km driving = 10 points. Check in daily, complete missions, and donate points at 100 points = RM1.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryBadge(
                Icons.local_fire_department_rounded,
                'Streak $_checkInStreak day${_checkInStreak == 1 ? '' : 's'}',
              ),
              _buildSummaryBadge(
                Icons.shield_outlined,
                'Safe $_safeDrivingDays/7',
              ),
              _buildSummaryBadge(Icons.eco_outlined, 'Eco $ecoDrivingScore'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInCard() {
    return _buildSurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: _brandColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Check-In',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _checkedInToday
                          ? 'You already checked in today.'
                          : 'Open the app every day to keep your streak alive.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final day = index + 1;
                final isComplete = day <= _visibleStreakProgress;
                final isNext =
                    !_checkedInToday && day == _visibleStreakProgress + 1;
                return Padding(
                  padding: EdgeInsets.only(right: day == 7 ? 0 : 10),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? _brandColor
                              : isNext
                              ? _brandColor.withValues(alpha: 0.12)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isNext ? _brandColor : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                )
                              : Text(
                                  '$day',
                                  style: TextStyle(
                                    color: isNext
                                        ? _brandColor
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Day $day',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                disabledBackgroundColor: Colors.green.shade200,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _isLoadingRewards ? null : _handleCheckIn,
              child: Text(
                _checkedInToday ? 'Checked In' : 'Check In',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Streak: $_checkInStreak day${_checkInStreak == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '+$_todayCheckInPoints Point${_todayCheckInPoints == 1 ? '' : 's'} ${_checkedInToday ? 'Today' : 'on next check-in'}',
                style: const TextStyle(
                  color: _brandColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Progress',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Points',
                '$totalPoints',
                Icons.stars_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Eco Score',
                '$ecoDrivingScore',
                Icons.eco_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Distance',
                '$totalDistanceKm km',
                Icons.route_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Charging',
                '$chargingSessions',
                Icons.ev_station_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildImpactMetric('$studentsHelped helped', 'students'),
              ),
              Container(width: 1, height: 38, color: Colors.grey.shade200),
              Expanded(
                child: _buildImpactMetric('$carbonSavedKg kg saved', 'carbon'),
              ),
              Container(width: 1, height: 38, color: Colors.grey.shade200),
              Expanded(
                child: _buildImpactMetric('$waterSavedLitres L', 'water'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return _buildSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _brandColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _brandColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetric(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection() {
    final missions = [
      {
        'title': 'Safe Driving',
        'subtitle': 'Complete 7 days with no alerts',
        'progress': _safeDrivingDays,
        'target': 7,
        'points': 300,
        'icon': Icons.shield_outlined,
        'done': _safeDrivingAwarded,
        'footer': _safeDrivingDays >= 7
            ? 'All clear this week. Bonus unlocked.'
            : 'Drive safely for ${7 - _safeDrivingDays} more days to earn this bonus.',
      },
      {
        'title': 'Eco Challenge',
        'subtitle': 'Maintain eco score above 90',
        'progress': _ecoChallengeDays,
        'target': 3,
        'points': 150,
        'icon': Icons.eco_outlined,
        'done': _ecoChallengeAwarded,
        'footer': ecoDrivingScore >= 90
            ? 'Eco driving is on track at $ecoDrivingScore.'
            : 'Raise your eco score above 90 to keep progress alive.',
      },
      {
        'title': 'Smart Charging',
        'subtitle': 'Charge during off-peak hours',
        'progress': _offPeakCharges,
        'target': 4,
        'points': 50,
        'icon': Icons.bolt_outlined,
        'done': _offPeakAwarded,
        'footer': _offPeakCharges >= 4
            ? 'Off-peak habit reached for this cycle.'
            : '${4 - _offPeakCharges} more off-peak sessions to go.',
      },
      {
        'title': 'Full Charge Sessions',
        'subtitle': 'Complete full charge sessions',
        'progress': _fullChargeSessions,
        'target': 3,
        'points': 20,
        'icon': Icons.battery_charging_full_outlined,
        'done': _fullChargeAwarded,
        'footer': _fullChargeSessions >= 3
            ? 'Full charge reward secured.'
            : '${3 - _fullChargeSessions} more full charges needed.',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Missions & Bonuses',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 10),
        ...missions.map((mission) {
          final progress =
              (mission['progress'] as int) / (mission['target'] as int);
          return _buildSurfaceCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _brandColor.withValues(alpha: 0.12),
                      child: Icon(
                        mission['icon'] as IconData,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mission['title'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            mission['subtitle'].toString(),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mission['done'] == true
                            ? _brandColor
                            : _brandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${mission['points']}',
                        style: TextStyle(
                          color: mission['done'] == true
                              ? Colors.white
                              : _brandColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress.clamp(0, 1).toDouble(),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _brandColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Progress: ${mission['progress']}/${mission['target']} days',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (mission['done'] == true)
                      const Text(
                        'Unlocked',
                        style: TextStyle(
                          color: _brandColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mission['footer'].toString(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDonationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Point Donation System',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 10),
        ..._donationCauses.map((cause) {
          final points = cause['recommendedPoints'] as int;
          return _buildSurfaceCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _brandColor.withValues(alpha: 0.12),
                      child: Icon(
                        cause['icon'] as IconData,
                        color: _brandColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cause['title'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$points points = RM ${(points / 100).toStringAsFixed(0)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () => _donatePoints(cause),
                      child: const Text('Donate'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: (cause['progress'] as double).clamp(0, 1).toDouble(),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _brandColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    cause['title'].toString().contains('Education')
                        ? 'You helped $studentsHelped students'
                        : cause['impact'].toString(),
                    style: const TextStyle(
                      color: _brandColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _donatePoints(Map<String, dynamic> cause) async {
    final points = cause['recommendedPoints'] as int;
    final title = cause['title'].toString();
    if (totalPoints < points) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points for this donation.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Donation'),
        content: Text(
          'Donate $points points to $title?\n\nThis equals RM ${(points / 100).toStringAsFixed(0)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      totalPoints -= points;
      if (title.contains('Education')) {
        studentsHelped += 1;
      }
    });

    await AppRepository.upsertCurrentUserRewards(
      points: totalPoints,
      stats: {
        'studentsHelped': studentsHelped,
        'carbonSavedKg': carbonSavedKg,
        'waterSavedLitres': waterSavedLitres,
      },
    );
    await AppRepository.logRewardNotification(
      title: 'Donation to $title',
      message: 'Your donation was successfully processed.',
      pointsDelta: -points,
      rewardKind: 'donation',
      timestamp: DateTime.now(),
    );

    if (!mounted) {
      return;
    }
    _showThankYouPopup(title);
  }

  Future<void> _showThankYouPopup(String cause) async {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: _brandColor, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Thank You!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your donation to $cause has been successfully processed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _brandColor),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
