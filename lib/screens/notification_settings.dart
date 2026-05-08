import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'alert.dart';
import 'charge.dart';
import 'home_driver.dart';
import 'noti.dart';
import 'rewards.dart';
import '../services/android_background_impact_service.dart';
import '../services/impact_detection_service.dart';
import '../services/notification_service.dart';
import '../services/web_monitoring_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const Color _primaryGreen = Color(0xFF1F8A3A);
  static const Color _softGreen = Color(0xFFF2F8F1);

  bool _notificationsEnabled = true;
  bool _impactAlertsEnabled = true;
  bool _backgroundMonitoringEnabled = false;
  LocationPermission _locationPermission = LocationPermission.denied;
  bool _locationServiceEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notificationsEnabled =
        await NotificationService.areNotificationsEnabled();
    final impactAlertsEnabled = kIsWeb
        ? WebMonitoringService.state.value.impactDetectionEnabled
        : await NotificationService.areImpactAlertsEnabled();
    final backgroundMonitoringEnabled = kIsWeb
        ? WebMonitoringService.state.value.backgroundSimulationEnabled
        : await ImpactDetectionService.backgroundAlertsEnabled();
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    final locationPermission = await Geolocator.checkPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _impactAlertsEnabled = impactAlertsEnabled;
      _backgroundMonitoringEnabled = backgroundMonitoringEnabled;
      _locationServiceEnabled = locationServiceEnabled;
      _locationPermission = locationPermission;
      _loading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await NotificationService.setNotificationsEnabled(value);
    if (kIsWeb) {
      await WebMonitoringService.setNotificationsEnabled(value);
    }
    if (value) {
      await NotificationService.requestSystemPermissions();
      await NotificationService.syncMessagingToken();
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Notifications enabled for this device.'
              : 'Notifications disabled for this device.',
        ),
      ),
    );
  }

  Future<void> _toggleImpactAlerts(bool value) async {
    setState(() {
      _impactAlertsEnabled = value;
    });
    if (value && !_notificationsEnabled) {
      await NotificationService.setNotificationsEnabled(true);
      await NotificationService.requestSystemPermissions();
      await NotificationService.syncMessagingToken();
      if (mounted) {
        setState(() {
          _notificationsEnabled = true;
        });
      }
    }
    if (kIsWeb) {
      await WebMonitoringService.setImpactDetectionEnabled(value);
    } else {
      await NotificationService.setImpactAlertsEnabled(value);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Impact alert notifications are enabled.'
              : 'Impact alert notifications are paused.',
        ),
      ),
    );
  }

  Future<void> _toggleBackgroundMonitoring(bool value) async {
    setState(() {
      _backgroundMonitoringEnabled = value;
    });

    if (kIsWeb) {
      if (value) {
        if (!_notificationsEnabled) {
          await NotificationService.setNotificationsEnabled(true);
          await WebMonitoringService.setNotificationsEnabled(true);
        }
        if (!_impactAlertsEnabled) {
          await WebMonitoringService.setImpactDetectionEnabled(true);
        }
        await WebMonitoringService.setBackgroundSimulationEnabled(true);
      } else {
        await WebMonitoringService.setBackgroundSimulationEnabled(false);
      }
    } else if (value) {
      if (!_notificationsEnabled) {
        await NotificationService.setNotificationsEnabled(true);
        await NotificationService.requestSystemPermissions();
        await NotificationService.syncMessagingToken();
      }
      if (!_impactAlertsEnabled) {
        await NotificationService.setImpactAlertsEnabled(true);
      }
      await ImpactDetectionService.setBackgroundAlertsEnabled(true);
      await NotificationService.requestSystemPermissions();
      await AndroidBackgroundImpactService.start();
    } else {
      await ImpactDetectionService.setBackgroundAlertsEnabled(false);
      await AndroidBackgroundImpactService.stop();
    }

    await _loadSettings();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Background impact monitoring is active.'
              : 'Background impact monitoring is off.',
        ),
      ),
    );
  }

  Future<void> _requestLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    } else if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }

    await _loadSettings();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _locationPermission == LocationPermission.always ||
                  _locationPermission == LocationPermission.whileInUse
              ? 'Location access is enabled for nearby responder and map features.'
              : 'Location permission is still limited. You can enable it in system settings.',
        ),
      ),
    );
  }

  Future<void> _openAppSettingsWithMessage(String label) async {
    if (kIsWeb) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use your browser site settings to adjust location and notification permissions.',
          ),
        ),
      );
      return;
    }
    await Geolocator.openAppSettings();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _pauseBackgroundMonitoring(
    int minutes,
    String label, {
    bool turnOffUntilManual = false,
  }) async {
    if (turnOffUntilManual) {
      if (kIsWeb) {
        await WebMonitoringService.setBackgroundSimulationEnabled(false);
        await WebMonitoringService.setImpactDetectionEnabled(false);
      } else {
        await ImpactDetectionService.setBackgroundAlertsEnabled(
          false,
          markPrompted: false,
        );
        await AndroidBackgroundImpactService.snooze(-1);
      }
      if (mounted) {
        setState(() {
          _backgroundMonitoringEnabled = false;
        });
      }
    } else if (minutes == 0) {
      if (kIsWeb) {
        await WebMonitoringService.setBackgroundSimulationEnabled(true);
        await WebMonitoringService.setImpactDetectionEnabled(true);
      } else {
        await ImpactDetectionService.setBackgroundAlertsEnabled(true);
        await AndroidBackgroundImpactService.snooze(0);
        await AndroidBackgroundImpactService.start();
      }
      if (mounted) {
        setState(() {
          _backgroundMonitoringEnabled = true;
        });
      }
    } else {
      if (kIsWeb) {
        await WebMonitoringService.setBackgroundSimulationEnabled(false);
      } else {
        await AndroidBackgroundImpactService.snooze(minutes);
      }
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: Color(0xFFE7EEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _primaryGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF161A1D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF5C6268),
                        height: 1.45,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryGreen,
        side: const BorderSide(color: Color(0xFFC9DDC7)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _pauseAction({
    required String label,
    required VoidCallback? onPressed,
    IconData leading = Icons.access_time_rounded,
    bool highlight = false,
  }) {
    return Material(
      color: highlight ? const Color(0xFFF3FAF1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? const Color(0xFFD8EAD5)
                  : const Color(0xFFE3E8E2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                leading,
                size: 20,
                color: highlight ? _primaryGreen : const Color(0xFF7B8288),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                    color: highlight ? _primaryGreen : const Color(0xFF161A1D),
                  ),
                ),
              ),
              Icon(
                highlight
                    ? Icons.play_circle_outline_rounded
                    : Icons.chevron_right_rounded,
                color: highlight ? _primaryGreen : const Color(0xFF7B8288),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF161A1D),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF5C6268),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: _primaryGreen,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFD4DAD4),
        ),
      ],
    );
  }

  Widget _statusSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE6)),
      ),
      child: child,
    );
  }

  bool get _hasLocationAccess =>
      _locationPermission == LocationPermission.always ||
      _locationPermission == LocationPermission.whileInUse;

  Widget _buildBottomNav(double bottomSystem) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottomSystem + 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildBottomTab(Icons.home, 'Home', false, compact, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DriverHomePage()),
                  );
                }),
              ),
              Expanded(
                child: _buildBottomTab(
                  Icons.ev_station,
                  'Charge',
                  false,
                  compact,
                  () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ChargePage()),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildBottomTab(
                  Icons.warning,
                  'Alert',
                  false,
                  compact,
                  () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AlertPage()),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildBottomTab(
                  Icons.notifications,
                  'Noti',
                  true,
                  compact,
                  () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationPage(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildBottomTab(
                  Icons.card_giftcard,
                  'Rewards',
                  false,
                  compact,
                  () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RewardsPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomTab(
    IconData icon,
    String label,
    bool isActive,
    bool compact,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 22 : 24,
              color: isActive ? _primaryGreen : Colors.grey,
            ),
            SizedBox(height: compact ? 3 : 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  color: isActive ? _primaryGreen : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _locationStatusLabel {
    if (!_locationServiceEnabled) {
      return 'Location services are off';
    }
    switch (_locationPermission) {
      case LocationPermission.always:
        return 'Always allowed';
      case LocationPermission.whileInUse:
        return 'Allowed while using app';
      case LocationPermission.deniedForever:
        return 'Denied in system settings';
      case LocationPermission.denied:
        return 'Not allowed yet';
      case LocationPermission.unableToDetermine:
        return 'Not determined';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unsupported =
        !(kIsWeb ||
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final bottomSystem = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: Color(0xFF161A1D),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF161A1D)),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                _settingsCard(
                  icon: Icons.location_on_outlined,
                  title: 'Location Access',
                  description:
                      'Nearby ambulance, technician, hospital, and charging support uses your device location.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusSurface(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF4B5258),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current location access',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _locationStatusLabel,
                                    style: TextStyle(
                                      color: _hasLocationAccess
                                          ? _primaryGreen
                                          : const Color(0xFF5C6268),
                                      fontWeight: _hasLocationAccess
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _hasLocationAccess
                                    ? _softGreen
                                    : const Color(0xFFF4F5F4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _hasLocationAccess ? 'Allowed' : 'Limited',
                                    style: TextStyle(
                                      color: _hasLocationAccess
                                          ? _primaryGreen
                                          : const Color(0xFF70777C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_hasLocationAccess) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: _primaryGreen,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : _requestLocationAccess,
                              icon: Icons.gps_fixed_rounded,
                              label: 'Request Again',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : () => _openAppSettingsWithMessage(
                                      'System settings opened for location access.',
                                    ),
                              icon: Icons.settings_outlined,
                              label: 'Open Settings',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _settingsCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'Emergency Notifications',
                  description:
                      'Control push notifications, impact alert popups, and dashboard updates.',
                  child: Column(
                    children: [
                      _statusSurface(
                        child: _toggleRow(
                          value: _notificationsEnabled && !unsupported,
                          onChanged: unsupported ? null : _toggleNotifications,
                          title: 'Enable push notifications',
                          description: unsupported
                              ? 'Notifications are not available on this platform.'
                              : 'Receive EVSmart+ notifications on this device.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statusSurface(
                        child: _toggleRow(
                          value:
                              _notificationsEnabled &&
                              _impactAlertsEnabled &&
                              !unsupported,
                          onChanged: unsupported ? null : _toggleImpactAlerts,
                          title: 'Allow impact alert notifications',
                          description:
                              'Shows Level 1 to Level 5 local impact warnings and review reminders.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : () async {
                                      if (!kIsWeb) {
                                        await NotificationService.requestSystemPermissions();
                                      }
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            kIsWeb
                                                ? 'Use your browser site settings if you need to allow notifications manually.'
                                                : 'Notification permission request sent again.',
                                          ),
                                        ),
                                      );
                                    },
                              icon: Icons.notifications_active_outlined,
                              label: 'Ask Permission',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : () => _openAppSettingsWithMessage(
                                      'System settings opened for notification access.',
                                    ),
                              icon: Icons.settings_outlined,
                              label: 'Open Settings',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _settingsCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Background Monitoring',
                  description:
                      'Run impact monitoring in the background, or pause it to reduce battery use and false alerts.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusSurface(
                        child: _toggleRow(
                          value: _backgroundMonitoringEnabled && !unsupported,
                          onChanged: unsupported
                              ? null
                              : _toggleBackgroundMonitoring,
                          title: 'Enable background monitoring',
                          description: unsupported
                              ? 'Background monitoring is not available on this platform.'
                              : 'If this is off, background impact monitoring stays stopped.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : () async {
                                      await AndroidBackgroundImpactService.openControls();
                                    },
                              icon: Icons.tune_rounded,
                              label: 'Open Pause Controls',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                              onPressed: unsupported
                                  ? null
                                  : () => _openAppSettingsWithMessage(
                                      'System settings opened for EVSmart+ background access.',
                                    ),
                              icon: Icons.settings_outlined,
                              label: 'Open System Settings',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Pause Monitoring For',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _pauseAction(
                        label: 'Pause 1 hour',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                60,
                                'Background monitoring paused for 1 hour.',
                              ),
                      ),
                      const SizedBox(height: 10),
                      _pauseAction(
                        label: 'Pause 5 hours',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                300,
                                'Background monitoring paused for 5 hours.',
                              ),
                      ),
                      const SizedBox(height: 10),
                      _pauseAction(
                        label: 'Pause 8 hours',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                480,
                                'Background monitoring paused for 8 hours.',
                              ),
                      ),
                      const SizedBox(height: 10),
                      _pauseAction(
                        label: 'Pause 10 hours',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                600,
                                'Background monitoring paused for 10 hours.',
                              ),
                      ),
                      const SizedBox(height: 10),
                      _pauseAction(
                        label: 'Until I turn it back on',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                -1,
                                'Background monitoring is off until you re-enable it.',
                                turnOffUntilManual: true,
                              ),
                      ),
                      const SizedBox(height: 10),
                      _pauseAction(
                        label: 'Turn monitoring back on',
                        onPressed: unsupported
                            ? null
                            : () => _pauseBackgroundMonitoring(
                                0,
                                'Background monitoring is active again.',
                              ),
                        leading: Icons.play_circle_outline_rounded,
                        highlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _settingsCard(
                  icon: Icons.info_outline_rounded,
                  title: 'How It Works',
                  description:
                      'Driver alerts, ambulance updates, and hospital dashboard changes all sync through Firebase in real time.',
                  child: SizedBox(
                    width: double.infinity,
                    child: _actionButton(
                      onPressed: unsupported
                          ? null
                          : () async {
                              await NotificationService.requestSystemPermissions();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notification permission request sent.',
                                  ),
                                ),
                              );
                            },
                      icon: Icons.notifications_active_outlined,
                      label: 'Request Permission Again',
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(bottomSystem),
    );
  }
}
