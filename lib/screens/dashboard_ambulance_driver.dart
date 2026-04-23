import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_repository.dart';

class DashboardAmbulanceDriverPage extends StatefulWidget {
  const DashboardAmbulanceDriverPage({super.key});

  @override
  State<DashboardAmbulanceDriverPage> createState() =>
      _DashboardAmbulanceDriverPageState();
}

class _DashboardAmbulanceDriverPageState
    extends State<DashboardAmbulanceDriverPage> {
  static const Color _brandGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF245B29);
  static const Color _canvas = Color(0xFFF4F7F2);
  static const Color _textPrimary = Color(0xFF223126);
  static const Color _textMuted = Color(0xFF6C756E);

  Map<String, dynamic> _profile = const <String, dynamic>{};
  Position? _currentPosition;
  String _currentLocationLabel = 'Fetching location';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _captureCurrentLocation();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final data = await AppRepository.getProfileByPath(
      AppRepository.ambulanceProfilesRef,
      uid,
    );

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      _profile = data;
      _currentLocationLabel =
          data['current_location']?.toString() ?? _currentLocationLabel;
    });
  }

  Future<void> _captureCurrentLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

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
      final locationName = AppRepository.inferLocationName(
        position.latitude,
        position.longitude,
      );

      await AppRepository.upsertAmbulanceProfile(uid, {
        'current_location': locationName,
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPosition = position;
        _currentLocationLabel = locationName;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _brandGreen,
        title: const Text('EVSmart+', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AppRepository.streamAlerts(),
        builder: (context, snapshot) {
          final alerts = (snapshot.data ?? const <Map<String, dynamic>>[])
              .where(_isRealFeedAlert)
              .toList(growable: false)
            ..sort(_compareAlerts);

          final nearbyAlerts = _filterNearbyAlerts(alerts);
          final weeklyAlerts = _weeklyAlerts(alerts);
          final incomingCases = nearbyAlerts
              .where((alert) => _impactLevel(alert) >= 4)
              .length;
          final levelFiveCount = nearbyAlerts
              .where((alert) => _impactLevel(alert) >= 5)
              .length;
          final levelFourCount = nearbyAlerts
              .where((alert) => _impactLevel(alert) == 4)
              .length;
          final totalHandled = alerts
              .where((alert) {
                final status = _statusLabel(alert).toLowerCase();
                return status.contains('report submitted') ||
                    status.contains('arrived');
              })
              .length;
          final mostCommonLevel = _mostCommonLevel(weeklyAlerts);
          final averageResponse = _averageResponseMinutes(weeklyAlerts);
          final recentCritical = nearbyAlerts
              .where((alert) => _impactLevel(alert) >= 4)
              .take(3)
              .toList(growable: false);

          return RefreshIndicator(
            color: _brandGreen,
            onRefresh: () async {
              await _captureCurrentLocation();
              await _loadProfile();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildHeroCard(
                  incomingCases: incomingCases,
                  levelFiveCount: levelFiveCount,
                  levelFourCount: levelFourCount,
                ),
                const SizedBox(height: 16),
                _buildFilterCard(
                  nearbyCount: nearbyAlerts.length,
                  incomingCases: incomingCases,
                ),
                const SizedBox(height: 16),
                _buildStatGrid(
                  incomingCases: incomingCases,
                  levelFiveCount: levelFiveCount,
                  levelFourCount: levelFourCount,
                  totalHandled: totalHandled,
                ),
                const SizedBox(height: 16),
                _buildWeeklyAnalytics(
                  casesThisWeek: weeklyAlerts.length,
                  mostCommonLevel: mostCommonLevel,
                  averageResponse: averageResponse,
                ),
                const SizedBox(height: 16),
                _buildRecentStatusCard(recentCritical),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard({
    required int incomingCases,
    required int levelFiveCount,
    required int levelFourCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25652B), Color(0xFF3C9350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F25652B),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _profile['driver_name']?.toString() ?? 'Ambulance Driver Dashboard',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Impact detection from EV drivers and manual SOS reports will appear here when users are unconscious or unavailable to reply in chat.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip('Incoming Cases', '$incomingCases live'),
              _buildHeroChip('Level 5', '$levelFiveCount critical'),
              _buildHeroChip('Level 4', '$levelFourCount high priority'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required int nearbyCount,
    required int incomingCases,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gps_fixed_rounded, color: _brandGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Nearby driver filtering',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'This page now holds the dashboard and filtering section that was removed from the home feed.',
            style: TextStyle(color: _textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoBadge(Icons.place_rounded, _currentLocationLabel),
              _buildInfoBadge(
                Icons.notifications_active_rounded,
                '$nearbyCount nearby alerts',
              ),
              _buildInfoBadge(
                Icons.local_hospital_rounded,
                '$incomingCases hospital-level cases',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid({
    required int incomingCases,
    required int levelFiveCount,
    required int levelFourCount,
    required int totalHandled,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth >= 380
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Incoming Cases',
                value: '$incomingCases',
                subtitle: 'Live Level 4 and 5 queue',
                accent: const Color(0xFFE67E22),
                icon: Icons.local_shipping_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Level 5 Critical',
                value: '$levelFiveCount',
                subtitle: 'Immediate life-safety cases',
                accent: const Color(0xFFE53935),
                icon: Icons.warning_amber_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Level 4 High',
                value: '$levelFourCount',
                subtitle: 'Hospital prep required',
                accent: const Color(0xFFF39C12),
                icon: Icons.priority_high_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                title: 'Handled Total',
                value: '$totalHandled',
                subtitle: 'Arrived or reported cases',
                accent: _brandGreen,
                icon: Icons.assignment_turned_in_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAnalytics({
    required int casesThisWeek,
    required int mostCommonLevel,
    required int averageResponse,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: _brandGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Weekly statistics',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMetricRow('Cases this week', '$casesThisWeek'),
          const SizedBox(height: 10),
          _buildMetricRow('Most common level', 'Level $mostCommonLevel'),
          const SizedBox(height: 10),
          _buildMetricRow('Avg response time', '$averageResponse mins'),
          const SizedBox(height: 10),
          _buildMetricRow(
            'Hospital dashboard sync',
            'Level 4 and 5 only',
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStatusCard(List<Map<String, dynamic>> alerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: _brandGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Recent status',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Text(
              'No live Level 4 or Level 5 cases right now.',
              style: TextStyle(color: _textMuted),
            )
          else
            Column(
              children: alerts.map(_buildRecentStatusTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentStatusTile(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppRepository.severityLabel(_impactLevel(alert)),
            style: TextStyle(
              color: _impactLevel(alert) >= 5
                  ? const Color(0xFFE53935)
                  : const Color(0xFFF39C12),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _headlineText(alert),
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_locationText(alert)} - ${_relativeTime(alert['timestamp'])}',
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _darkGreen),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: _darkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _darkGreen,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  bool _isRealFeedAlert(Map<String, dynamic> alert) {
    final alertId = alert['alert_id']?.toString().trim() ?? '';
    final userId = alert['user_id']?.toString().trim() ?? '';
    final timestamp = alert['timestamp']?.toString().trim() ?? '';
    final source = alert['source']?.toString().toLowerCase() ?? '';
    final type = alert['type']?.toString().toLowerCase() ?? '';
    final sourceDetail = alert['source_detail']?.toString().toLowerCase() ?? '';

    return alertId.isNotEmpty &&
        userId.isNotEmpty &&
        timestamp.isNotEmpty &&
        (source == 'sensor' ||
            source == 'button' ||
            type == 'auto' ||
            type == 'manual' ||
            sourceDetail.contains('impact') ||
            sourceDetail.contains('manual') ||
            sourceDetail.contains('accelerometer'));
  }

  List<Map<String, dynamic>> _filterNearbyAlerts(
    List<Map<String, dynamic>> alerts,
  ) {
    if (_currentPosition == null) {
      return alerts;
    }

    return alerts.where((alert) {
      final lat = (alert['latitude'] as num?)?.toDouble();
      final lng = (alert['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return true;
      }

      final meters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );
      return meters <= 10000;
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _weeklyAlerts(List<Map<String, dynamic>> alerts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return alerts.where((alert) {
      final timestamp = AppRepository.parseTimestamp(alert['timestamp']);
      return !timestamp.isBefore(cutoff);
    }).toList(growable: false);
  }

  int _compareAlerts(Map<String, dynamic> left, Map<String, dynamic> right) {
    final severityCompare = _impactLevel(right).compareTo(_impactLevel(left));
    if (severityCompare != 0) {
      return severityCompare;
    }
    return AppRepository.parseTimestamp(
      right['timestamp'],
    ).compareTo(AppRepository.parseTimestamp(left['timestamp']));
  }

  int _impactLevel(Map<String, dynamic> alert) {
    return ((alert['impact_level'] ?? 1) as num).toInt().clamp(1, 5);
  }

  int _mostCommonLevel(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) {
      return 4;
    }

    final counts = <int, int>{};
    for (final alert in alerts) {
      final level = _impactLevel(alert);
      counts[level] = (counts[level] ?? 0) + 1;
    }

    return counts.entries.reduce((left, right) {
      if (left.value == right.value) {
        return left.key >= right.key ? left : right;
      }
      return left.value >= right.value ? left : right;
    }).key;
  }

  int _averageResponseMinutes(List<Map<String, dynamic>> alerts) {
    final values = <int>[];
    for (final alert in alerts) {
      final acceptedAt = DateTime.tryParse(
        alert['accepted_at']?.toString() ?? '',
      );
      final arrivedAt = DateTime.tryParse(
        alert['arrival_timestamp']?.toString() ?? '',
      );

      if (acceptedAt != null && arrivedAt != null) {
        values.add(arrivedAt.difference(acceptedAt).inMinutes.abs());
      }
    }

    if (values.isEmpty) {
      return 7;
    }

    final total = values.reduce((left, right) => left + right);
    return (total / values.length).round();
  }

  String _headlineText(Map<String, dynamic> alert) {
    return alert['vehicle_status']?.toString().trim().isNotEmpty == true
        ? alert['vehicle_status'].toString().trim()
        : alert['title']?.toString().trim().isNotEmpty == true
            ? alert['title'].toString().trim()
            : AppRepository.severityExplanation(_impactLevel(alert));
  }

  String _locationText(Map<String, dynamic> alert) {
    final location = alert['location_name']?.toString().trim() ?? '';
    final road = alert['road_name']?.toString().trim() ?? '';
    if (location.isEmpty && road.isEmpty) {
      return 'Unknown location';
    }
    if (road.isEmpty) {
      return location;
    }
    if (location.isEmpty) {
      return road;
    }
    return '$location - $road';
  }

  String _statusLabel(Map<String, dynamic> alert) {
    return alert['status']?.toString().trim() ?? 'Available';
  }

  String _relativeTime(Object? value) {
    final date = AppRepository.parseTimestamp(value).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}
