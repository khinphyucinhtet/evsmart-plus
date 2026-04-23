import 'dart:async';
import 'package:flutter/material.dart';

import 'package:evsmart_plus/services/app_repository.dart';
import 'package:evsmart_plus/widgets/dashboard_layout.dart';
import '../screens/ambulance_dashboard.dart';
import '../screens/insurance_dashboard.dart';

class DashboardRouter extends StatefulWidget {
  const DashboardRouter({super.key});

  @override
  State<DashboardRouter> createState() => _DashboardRouterState();
}

class _DashboardRouterState extends State<DashboardRouter> {
  DashboardRole _activeRole = DashboardRole.ambulance;
  DateTime _liveTimestamp = DateTime.now();
  DateTimeRange? _selectedRange;
  final Set<String> _selectedAlertIds = <String>{};
  int _cleanupDays = 2;
  bool _isDeleting = false;
  bool _isClearing = false;
  bool _isReady = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _liveTimestamp = DateTime.now();
        });
      }
    });
    _resolveInitialRole();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _resolveInitialRole() async {
    final roleFromUrl = Uri.base.queryParameters['role'];
    final profile = await AppRepository.getCurrentUserProfile();
    final roleFromProfile = profile?['role']?.toString();

    if (!mounted) {
      return;
    }

    setState(() {
      _activeRole = _normalizeRole(roleFromUrl ?? roleFromProfile);
      _isReady = true;
    });
  }

  DashboardRole _normalizeRole(String? role) {
    final normalized = role?.toLowerCase().trim() ?? '';

    if (normalized.contains('ambulance') || normalized.contains('hospital')) {
      return DashboardRole.ambulance;
    }

    if (normalized.contains('insurance')) {
      return DashboardRole.insurance;
    }

    return DashboardRole.ambulance;
  }

  List<Map<String, dynamic>> _filterAlertsByRange(
    List<Map<String, dynamic>> alerts,
  ) {
    if (_selectedRange == null) {
      return alerts;
    }

    final start = DateTime(
      _selectedRange!.start.year,
      _selectedRange!.start.month,
      _selectedRange!.start.day,
    );
    final end = DateTime(
      _selectedRange!.end.year,
      _selectedRange!.end.month,
      _selectedRange!.end.day,
      23,
      59,
      59,
    );

    return alerts.where((alert) {
      final timestamp = AppRepository.parseTimestamp(
        alert['timestamp'],
      ).toLocal();
      return !timestamp.isBefore(start) && !timestamp.isAfter(end);
    }).toList()..sort((left, right) {
      return AppRepository.parseTimestamp(
        right['timestamp'],
      ).compareTo(AppRepository.parseTimestamp(left['timestamp']));
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedRange,
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedRange = selected;
      });
    }
  }

  Future<void> _deleteSelectedAlerts() async {
    if (_selectedAlertIds.isEmpty) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final ids = _selectedAlertIds.toList(growable: false);
    await AppRepository.deleteAlerts(ids);
    await AppRepository.deleteNotificationsByAlertIds(ids);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlertIds.clear();
      _isDeleting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${ids.length} log(s) deleted successfully.')),
    );
  }

  Future<void> _clearOldLogs() async {
    setState(() {
      _isClearing = true;
    });

    final removed = await AppRepository.deleteAlertsOlderThan(_cleanupDays);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlertIds.clear();
      _isClearing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed == 0
              ? 'No logs older than $_cleanupDays days were found.'
              : '$removed old log(s) cleared.',
        ),
      ),
    );
  }

  void _toggleSelection(String alertId, bool selected) {
    setState(() {
      if (selected) {
        _selectedAlertIds.add(alertId);
      } else {
        _selectedAlertIds.remove(alertId);
      }
    });
  }

  void _toggleBatchSelection(List<String> alertIds, bool selected) {
    setState(() {
      for (final id in alertIds) {
        if (selected) {
          _selectedAlertIds.add(id);
        } else {
          _selectedAlertIds.remove(id);
        }
      }
    });
  }

  String _selectedRangeLabel() {
    if (_selectedRange == null) {
      return 'All live logs are visible. Select a calendar date range to narrow the dashboard feed.';
    }

    return '${_formatDate(_selectedRange!.start)} to ${_formatDate(_selectedRange!.end)}';
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Widget _buildDashboard(
    List<Map<String, dynamic>> alerts,
    List<Map<String, dynamic>> notifications,
  ) {
    switch (_activeRole) {
      case DashboardRole.ambulance:
        return AmbulanceDashboard(
          alerts: alerts,
          notifications: notifications,
          liveTimestamp: _liveTimestamp,
          selectedAlertIds: _selectedAlertIds,
          onToggleSelection: _toggleSelection,
          onToggleBatchSelection: _toggleBatchSelection,
        );
      case DashboardRole.insurance:
        return InsuranceDashboard(
          alerts: alerts,
          notifications: notifications,
          liveTimestamp: _liveTimestamp,
          selectedAlertIds: _selectedAlertIds,
          onToggleSelection: _toggleSelection,
          onToggleBatchSelection: _toggleBatchSelection,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamAlerts(),
      builder: (context, alertSnapshot) {
        final allAlerts = alertSnapshot.data ?? const <Map<String, dynamic>>[];
        final filteredAlerts = _filterAlertsByRange(allAlerts);
        _selectedAlertIds.removeWhere((id) {
          return !filteredAlerts.any((alert) => _alertId(alert) == id);
        });

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: AppRepository.streamNotifications(),
          builder: (context, notificationSnapshot) {
            final notifications =
                notificationSnapshot.data ?? const <Map<String, dynamic>>[];

            return DashboardLayout(
              activeRole: _activeRole,
              onRoleSelected: (role) {
                setState(() {
                  _activeRole = role;
                  _selectedAlertIds.clear();
                });
              },
              liveTimestamp: _liveTimestamp,
              selectedRangeLabel: _selectedRangeLabel(),
              onPickDateRange: _pickDateRange,
              onClearDateRange: () {
                setState(() {
                  _selectedRange = null;
                });
              },
              onRefresh: () {
                setState(() {
                  _liveTimestamp = DateTime.now();
                });
              },
              cleanupDays: _cleanupDays,
              onCleanupDaysChanged: (value) {
                if (value != null) {
                  setState(() {
                    _cleanupDays = value;
                  });
                }
              },
              onClearLogs: _clearOldLogs,
              onDeleteSelected: _deleteSelectedAlerts,
              selectedCount: _selectedAlertIds.length,
              logCount: filteredAlerts.length,
              isClearing: _isClearing,
              isDeleting: _isDeleting,
              notifications: notifications,
              child: _buildDashboard(filteredAlerts, notifications),
            );
          },
        );
      },
    );
  }

  String _alertId(Map<String, dynamic> alert) {
    return alert['alert_id']?.toString() ?? alert['id']?.toString() ?? '';
  }
}
