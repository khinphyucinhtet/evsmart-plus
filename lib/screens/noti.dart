import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_repository.dart';
import '../services/impact_detection_service.dart';
import 'alert.dart';
import 'app_header.dart';
import 'charge.dart';
import 'global_search.dart';
import 'home_driver.dart';
import 'rewards.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  static const Color _primaryGreen = Color(0xFF2E7D32);

  int selectedTab = 3;
  String filter = 'All';
  late final ImpactDetectionService _impactService;
  bool _isImpactDialogVisible = false;
  double _currentLatitude = 3.1390;
  double _currentLongitude = 101.6869;
  DateTime? _selectedHistoryDate;
  DateTime? _selectedNotificationDate;
  String _rewardsHistoryFilter = 'Today';
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    _impactService.start();
    _loadLocation();
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

  String _formatTimestamp(Object? value) {
    final raw = value?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) {
      return '-';
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAlertTime(Object? value) {
    final raw = value?.toString();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) {
      return '-';
    }

    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }

  String _formatDateLabel(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _historyForDisplay(
    List<Map<String, dynamic>> alerts,
  ) {
    final now = DateTime.now();
    final lastSevenDaysStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    return alerts.where((alert) {
      final timestamp = AppRepository.parseTimestamp(
        alert['timestamp'],
      ).toLocal();
      if (_selectedHistoryDate != null) {
        return _isSameDate(timestamp, _selectedHistoryDate!);
      }
      return !timestamp.isBefore(lastSevenDaysStart);
    }).toList();
  }

  List<Map<String, dynamic>> _notificationsForDisplay(
    List<Map<String, dynamic>> notifications,
  ) {
    if (_selectedNotificationDate == null) {
      return notifications;
    }

    return notifications.where((item) {
      final timestamp = AppRepository.parseTimestamp(
        item['timestamp'],
      ).toLocal();
      return _isSameDate(timestamp, _selectedNotificationDate!);
    }).toList();
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

  String _sourceText(Map<String, dynamic>? alert) {
    final source = alert?['source']?.toString() ?? '';
    final alertType = alert?['alert_type']?.toString() ?? '';
    if (source.contains('accelerometer') || alertType == 'auto') {
      return 'Automatic sensor detection';
    }
    if (source.contains('manual') || alertType == 'manual') {
      return 'Manual control panel trigger';
    }
    return 'Alert synced';
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

  String _notificationId(Map<String, dynamic> item) {
    return item['notification_id']?.toString() ??
        '${item['timestamp']}-${item['title']}-${item['message']}';
  }

  String _notificationType(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'System';
    return type == 'Reward' ? 'Rewards' : type;
  }

  List<Map<String, dynamic>> _rewardsNotificationsForDisplay(
    List<Map<String, dynamic>> notifications,
  ) {
    final filtered = _notificationsForDisplay(notifications);
    final now = DateTime.now();

    return filtered.where((item) {
      final timestamp = AppRepository.parseTimestamp(
        item['timestamp'],
      ).toLocal();
      if (_rewardsHistoryFilter == 'Today') {
        return _isSameDate(timestamp, now);
      }
      return now.difference(timestamp).inDays < 7;
    }).toList();
  }

  String _alertCardId(Map<String, dynamic> alert) {
    return alert['alert_id']?.toString() ??
        '${alert['timestamp']}-${alert['title']}';
  }

  void _setFilter(String label) {
    setState(() {
      filter = label;
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(Iterable<String> ids) {
    final visibleIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (visibleIds.isEmpty) {
      return;
    }

    setState(() {
      final allSelected = visibleIds.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectionMode = true;
        _selectedIds.addAll(visibleIds);
      }

      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<bool> _confirmDeleteNotification(Map<String, dynamic> item) async {
    final notificationId = item['notification_id']?.toString();
    if (notificationId == null || notificationId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This notification cannot be deleted yet.'),
          ),
        );
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete notification?'),
          content: const Text(
            'This removes the selected notification from your notification list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _primaryGreen),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    await AppRepository.deleteNotification(notificationId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
    }
    return true;
  }

  Future<bool> _confirmDeleteAlert(Map<String, dynamic> alert) async {
    final alertId = alert['alert_id']?.toString();
    if (alertId == null || alertId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This alert cannot be deleted yet.')),
        );
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete alert log?'),
          content: const Text(
            'This removes the alert from the database history and the linked alert notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _primaryGreen),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    await Future.wait([
      AppRepository.deleteAlert(alertId),
      AppRepository.deleteNotificationsByAlertIds([alertId]),
    ]);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert log deleted')));
    }
    return true;
  }

  Future<void> _deleteSelectedEntries() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    final count = _selectedIds.length;
    final isAlertFilter = filter == 'Alert';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isAlertFilter
                ? 'Delete selected alert logs?'
                : 'Delete selected notifications?',
          ),
          content: Text(
            isAlertFilter
                ? 'This will remove $count alert log(s) from the alert database and linked notifications.'
                : 'This will remove $count notification(s) from the notification list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _primaryGreen),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final ids = _selectedIds.toList();
    if (isAlertFilter) {
      await Future.wait([
        AppRepository.deleteAlerts(ids),
        AppRepository.deleteNotificationsByAlertIds(ids),
      ]);
    } else {
      await AppRepository.deleteNotifications(ids);
    }

    if (!mounted) {
      return;
    }

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlertFilter
              ? '$count alert log(s) deleted'
              : '$count notification(s) deleted',
        ),
      ),
    );
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
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _pickNotificationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedNotificationDate ?? now,
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
      _selectedNotificationDate = selected;
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystem = MediaQuery.of(context).padding.bottom;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamNotifications(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <Map<String, dynamic>>[];
        final filteredNotifications = notifications
            .where(
              (item) => filter == 'All' || _notificationType(item) == filter,
            )
            .toList();
        final visibleAllNotifications = filter == 'All'
            ? _notificationsForDisplay(filteredNotifications)
            : const <Map<String, dynamic>>[];
        final visibleRewardsNotifications = filter == 'Rewards'
            ? _rewardsNotificationsForDisplay(filteredNotifications)
            : const <Map<String, dynamic>>[];

        return Scaffold(
          backgroundColor: Colors.grey[100],
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
                  child: Column(
                    children: [
                      buildFilter(),
                      Expanded(
                        child: filter == 'Alert'
                            ? StreamBuilder<List<Map<String, dynamic>>>(
                                stream: AppRepository.streamAlerts(),
                                builder: (context, alertSnapshot) {
                                  final alerts =
                                      alertSnapshot.data ??
                                      const <Map<String, dynamic>>[];
                                  final visibleAlerts = _historyForDisplay(
                                    alerts,
                                  );
                                  final visibleIds = visibleAlerts
                                      .map(_alertCardId)
                                      .toList();

                                  return Column(
                                    children: [
                                      if (_selectionMode)
                                        _buildSelectionToolbar(visibleIds),
                                      Expanded(
                                        child: _buildAlertHistoryContent(
                                          visibleAlerts,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : filter == 'All'
                            ? Column(
                                children: [
                                  if (_selectionMode)
                                    _buildSelectionToolbar(
                                      visibleAllNotifications
                                          .map(_notificationId)
                                          .toList(),
                                    ),
                                  Expanded(
                                    child: _buildAllNotificationsContent(
                                      visibleAllNotifications,
                                    ),
                                  ),
                                ],
                              )
                            : filter == 'Rewards'
                            ? Column(
                                children: [
                                  if (_selectionMode)
                                    _buildSelectionToolbar(
                                      visibleRewardsNotifications
                                          .map(_notificationId)
                                          .toList(),
                                    ),
                                  Expanded(
                                    child: _buildRewardsContent(
                                      visibleRewardsNotifications,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  if (_selectionMode)
                                    _buildSelectionToolbar(
                                      filteredNotifications
                                          .map(_notificationId)
                                          .toList(),
                                    ),
                                  Expanded(
                                    child: _buildNotificationList(
                                      filteredNotifications,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
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

  Widget buildFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            filterButton('All'),
            const SizedBox(width: 8),
            filterButton('Alert'),
            const SizedBox(width: 8),
            filterButton('System'),
            const SizedBox(width: 8),
            filterButton('Rewards'),
          ],
        ),
      ),
    );
  }

  Widget filterButton(String label) {
    final active = filter == label;

    return ElevatedButton(
      onPressed: () {
        _setFilter(label);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? _primaryGreen : Colors.white,
        foregroundColor: active ? Colors.white : Colors.black,
        elevation: active ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }

  Widget _buildSelectionToolbar(List<String> currentIds) {
    final selectedCount = _selectedIds.length;
    final label = filter == 'Alert'
        ? '$selectedCount alert log(s) selected'
        : '$selectedCount notification(s) selected';
    final allSelected =
        currentIds.isNotEmpty && currentIds.every(_selectedIds.contains);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => _toggleSelectAll(currentIds),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  allSelected ? 'Clear all' : 'Select all',
                  style: const TextStyle(color: _primaryGreen, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: _clearSelection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _primaryGreen, fontSize: 13),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _deleteSelectedEntries,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return const Center(child: Text('No notifications yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final item = notifications[index];
        final notificationId = _notificationId(item);

        return Dismissible(
          key: ValueKey('notification-$notificationId'),
          direction: _selectionMode
              ? DismissDirection.none
              : DismissDirection.endToStart,
          confirmDismiss: _selectionMode
              ? null
              : (_) => _confirmDeleteNotification(item),
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerRight,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white),
                SizedBox(height: 6),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          child: buildNotificationCard(item),
        );
      },
    );
  }

  Widget _buildRewardsContent(List<Map<String, dynamic>> notifications) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Text(
              'Rewards History',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _primaryGreen,
              ),
            ),
            const Spacer(),
            _buildRewardsHistoryChip('Today'),
            const SizedBox(width: 8),
            _buildRewardsHistoryChip('Weekly'),
          ],
        ),
        const SizedBox(height: 10),
        if (notifications.isEmpty)
          _buildRewardsEmptyState()
        else
          ...notifications.map(_buildRewardHistoryCard),
      ],
    );
  }

  Widget _buildRewardsHistoryChip(String label) {
    final active = _rewardsHistoryFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          _rewardsHistoryFilter = label;
          _selectionMode = false;
          _selectedIds.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? _primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: const Text(
        'No rewards activity for the selected filter yet.',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRewardHistoryCard(Map<String, dynamic> item) {
    final notificationId = _notificationId(item);
    final selected = _selectedIds.contains(notificationId);
    final points = (item['points_delta'] as num?)?.toInt();

    return Dismissible(
      key: ValueKey('reward-$notificationId'),
      direction: _selectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: _selectionMode
          ? null
          : (_) => _confirmDeleteNotification(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 6),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _enterSelectionMode(notificationId),
        onTap: _selectionMode ? () => _toggleSelection(notificationId) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F8F1) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: _primaryGreen, width: 1.3)
                : null,
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _primaryGreen.withValues(alpha: 0.12),
                child: Icon(
                  _rewardIconForNotification(item),
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['title']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_selectionMode)
                          Checkbox(
                            value: selected,
                            activeColor: _primaryGreen,
                            onChanged: (_) => _toggleSelection(notificationId),
                          )
                        else if (points != null)
                          Text(
                            '${points > 0 ? '+' : ''}$points',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: points < 0 ? Colors.red : _primaryGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatRewardTime(
                        AppRepository.parseTimestamp(
                          item['timestamp'],
                        ).toLocal(),
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if ((item['message']?.toString().trim().isNotEmpty ??
                        false))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item['message'].toString(),
                          style: const TextStyle(color: Colors.black87),
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
  }

  Widget _buildAllNotificationsContent(
    List<Map<String, dynamic>> notifications,
  ) {
    final subtitle = _selectedNotificationDate == null
        ? 'Showing notifications from alerts, system updates, rewards, and messages.'
        : 'Showing notifications for ${_formatDateLabel(_selectedNotificationDate!)}.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'All Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _primaryGreen,
                ),
              ),
            ),
            if (_selectedNotificationDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedNotificationDate = null;
                    _selectionMode = false;
                    _selectedIds.clear();
                  });
                },
                child: const Text(
                  'Show all',
                  style: TextStyle(color: _primaryGreen),
                ),
              ),
            IconButton(
              onPressed: _pickNotificationDate,
              icon: const Icon(
                Icons.calendar_month_rounded,
                color: _primaryGreen,
              ),
              tooltip: 'Filter by date',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(
          'Swipe left to delete one notification, or long-press a card to select multiple items.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (notifications.isEmpty)
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
                  Icons.notifications_off_outlined,
                  size: 38,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedNotificationDate == null
                      ? 'No notifications available yet.'
                      : 'No notifications found for the selected date.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ...notifications.map(buildNotificationCard),
      ],
    );
  }

  Widget _buildAlertHistoryContent(List<Map<String, dynamic>> alerts) {
    final subtitle = _selectedHistoryDate == null
        ? 'Showing the latest incident records from the last 7 days.'
        : 'Showing alerts for ${_formatDateLabel(_selectedHistoryDate!)}.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                    _selectionMode = false;
                    _selectedIds.clear();
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
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(
          'Swipe left to delete one log, or long-press a card to select multiple logs and use Select all.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
          ...alerts.map(_buildAlertHistoryCard),
      ],
    );
  }

  Widget _buildAlertHistoryCard(Map<String, dynamic> alert) {
    final cardId = _alertCardId(alert);
    final level = (alert['impact_level'] as num?)?.toInt() ?? 0;
    final severityColor = _severityColor(level);
    final selected = _selectedIds.contains(cardId);

    return Dismissible(
      key: ValueKey('alert-$cardId'),
      direction: _selectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: _selectionMode ? null : (_) => _confirmDeleteAlert(alert),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(height: 6),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _enterSelectionMode(cardId),
        onTap: _selectionMode ? () => _toggleSelection(cardId) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F8F1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: _primaryGreen, width: 1.4)
                : null,
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: severityColor.withValues(alpha: 0.14),
                child: Icon(
                  level >= 4
                      ? Icons.warning_amber_rounded
                      : Icons.health_and_safety_outlined,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert['title']?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_selectionMode)
                          Checkbox(
                            value: selected,
                            activeColor: _primaryGreen,
                            onChanged: (_) => _toggleSelection(cardId),
                          )
                        else
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
                    const SizedBox(height: 4),
                    Text(
                      'Alert Type: ${_alertTypeForLevel(level)}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Trigger Source: ${_sourceText(alert)}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Severity: ${alert['severity']?.toString() ?? AppRepository.severityLabel(level)}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Vehicle Status: ${alert['vehicle_condition']?.toString() ?? alert['vehicle_status']?.toString() ?? '-'}',
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Location: ${_locationText(alert)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Action Taken: ${alert['status']?.toString() ?? '-'}',
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatAlertTime(alert['timestamp']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
  }

  Widget buildNotificationCard(Map<String, dynamic> item) {
    final type = _notificationType(item);
    final notificationId = _notificationId(item);
    final selected = _selectedIds.contains(notificationId);
    late final Color iconColor;
    late final IconData icon;

    if (type == 'Alert') {
      iconColor = Colors.red;
      icon = Icons.warning_rounded;
    } else if (type == 'Rewards') {
      iconColor = Colors.orange;
      icon = Icons.emoji_events;
    } else if (type == 'Message') {
      iconColor = Colors.blue;
      icon = Icons.mail_outline_rounded;
    } else {
      iconColor = _primaryGreen;
      icon = Icons.notifications;
    }

    return GestureDetector(
      onLongPress: () => _enterSelectionMode(notificationId),
      onTap: _selectionMode ? () => _toggleSelection(notificationId) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F8F1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: _primaryGreen, width: 1.3)
              : null,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_selectionMode)
                        Checkbox(
                          value: selected,
                          activeColor: _primaryGreen,
                          onChanged: (_) => _toggleSelection(notificationId),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['message']?.toString() ?? '-',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(item['timestamp']),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _rewardIconForNotification(Map<String, dynamic> item) {
    final rewardKind = item['reward_kind']?.toString().toLowerCase() ?? '';
    final title = item['title']?.toString().toLowerCase() ?? '';

    if (rewardKind.contains('donation') || title.contains('donation')) {
      return Icons.volunteer_activism_rounded;
    }
    if (rewardKind.contains('eco') || title.contains('eco')) {
      return Icons.eco_rounded;
    }
    if (rewardKind.contains('safe') || title.contains('safe driving')) {
      return Icons.shield_rounded;
    }
    if (rewardKind.contains('charging') || title.contains('charging')) {
      return Icons.bolt_rounded;
    }
    if (rewardKind.contains('full_charge') || title.contains('full charge')) {
      return Icons.battery_charging_full_rounded;
    }
    if (rewardKind.contains('check_in') || title.contains('check-in')) {
      return Icons.local_fire_department_rounded;
    }
    return Icons.emoji_events_rounded;
  }

  String _formatRewardTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }
    return '${difference.inDays} days ago';
  }

  Color _severityColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF2E7D32);
      case 2:
        return const Color(0xFFEF6C00);
      case 3:
        return const Color(0xFFFFA000);
      case 4:
        return const Color(0xFFE53935);
      case 5:
        return const Color(0xFFB71C1C);
      default:
        return Colors.grey.shade500;
    }
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
        if (index == 3) {
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

        if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AlertPage()),
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
