import 'package:flutter/material.dart';

import '../widgets/dashboard_layout.dart';
import '../widgets/dashboard_notification_feed.dart';

class InsuranceDashboard extends StatelessWidget {
  const InsuranceDashboard({
    super.key,
    required this.alerts,
    required this.notifications,
    required this.liveTimestamp,
    required this.selectedAlertIds,
    required this.onToggleSelection,
    required this.onToggleBatchSelection,
  });

  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> notifications;
  final DateTime liveTimestamp;
  final Set<String> selectedAlertIds;
  final void Function(String alertId, bool selected) onToggleSelection;
  final void Function(List<String> alertIds, bool selected)
  onToggleBatchSelection;

  @override
  Widget build(BuildContext context) {
    return DashboardNotificationFeed(
      role: DashboardRole.insurance,
      alerts: alerts,
      notifications: notifications,
      selectedAlertIds: selectedAlertIds,
      onToggleSelection: onToggleSelection,
      onToggleBatchSelection: onToggleBatchSelection,
    );
  }
}
