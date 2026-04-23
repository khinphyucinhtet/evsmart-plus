import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'dashboard_layout.dart';
import 'info_card.dart';
import 'severity_badge.dart';

class DashboardNotificationFeed extends StatelessWidget {
  const DashboardNotificationFeed({
    super.key,
    required this.role,
    required this.alerts,
    required this.notifications,
    required this.selectedAlertIds,
    required this.onToggleSelection,
    required this.onToggleBatchSelection,
  });

  final DashboardRole role;
  final List<Map<String, dynamic>> alerts;
  final List<Map<String, dynamic>> notifications;
  final Set<String> selectedAlertIds;
  final void Function(String alertId, bool selected) onToggleSelection;
  final void Function(List<String> alertIds, bool selected)
  onToggleBatchSelection;

  @override
  Widget build(BuildContext context) {
    final visibleAlerts = _visibleAlerts();
    final visibleIds = visibleAlerts
        .map(_alertId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(selectedAlertIds.contains);
    final updateNotifications = notifications
        .where(_matchesRoleNotification)
        .take(6)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricCard(
              label: 'Visible notifications',
              value: '${visibleAlerts.length}',
              helper: _feedSummary(),
            ),
            _buildMetricCard(
              label: 'Selected',
              value: '${selectedAlertIds.intersection(visibleIds).length}',
              helper: 'Use Select all to bulk manage the list.',
            ),
            _buildMetricCard(
              label: 'Live updates',
              value: '${updateNotifications.length}',
              helper: 'Firebase updates appear here in real time.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        InfoCard(
          title: '${role.label} Notifications',
          subtitle:
              'Simple notification-style cards synced from Firebase for ${role.label.toLowerCase()}.',
          icon: Icons.notifications_active_rounded,
          accentColor: role.accentColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: visibleIds.isEmpty
                        ? null
                        : () => onToggleBatchSelection(
                            visibleIds.toList(growable: false),
                            !allVisibleSelected,
                          ),
                    icon: Icon(
                      allVisibleSelected
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                    ),
                    label: Text(
                      allVisibleSelected ? 'Clear visible' : 'Select all',
                    ),
                  ),
                  Chip(
                    label: Text(_feedSummary()),
                    avatar: Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: role.accentColor,
                    ),
                    backgroundColor: role.accentColor.withValues(alpha: 0.08),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (visibleAlerts.isEmpty)
                _buildEmptyState(
                  'No live notifications yet',
                  'New Firebase alerts and responder updates will appear here automatically.',
                )
              else
                ...visibleAlerts.map(_buildAlertCard),
            ],
          ),
        ),
        const SizedBox(height: 18),
        InfoCard(
          title: 'Real-Time Updates',
          subtitle:
              'Recent Firebase notification entries, including responder updates and account changes.',
          icon: Icons.sync_rounded,
          accentColor: role.accentColor,
          child: updateNotifications.isEmpty
              ? _buildEmptyState(
                  'No extra updates yet',
                  'Profile and responder update notifications will show here after the next sync.',
                )
              : Column(
                  children: updateNotifications
                      .map(_buildNotificationUpdate)
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String helper,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: role.accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final alertId = _alertId(alert);
    final level = _impactLevel(alert);
    final selected = selectedAlertIds.contains(alertId);
    final accountUpdate = _accountUpdateLine(alert);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: role.accentColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: alertId.isEmpty
                    ? null
                    : (value) => onToggleSelection(alertId, value ?? false),
                activeColor: role.accentColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert['title']?.toString().trim().isNotEmpty == true
                          ? alert['title'].toString().trim()
                          : AppRepository.severityLabel(level),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _locationText(alert),
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SeverityBadge.fromSeverity('Level $level'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Icons.person_outline_rounded, _driverName(alert)),
              _metaChip(Icons.ev_station_rounded, _vehicleLabel(alert)),
              _metaChip(
                Icons.schedule_rounded,
                _formatTimestamp(alert['timestamp']),
              ),
              _metaChip(Icons.info_outline_rounded, _statusText(alert)),
            ],
          ),
          const SizedBox(height: 14),
          _detailLine('Summary', _summaryForRole(alert)),
          const SizedBox(height: 8),
          _detailLine('Action', _actionText(alert)),
          if (accountUpdate != null) ...[
            const SizedBox(height: 8),
            _detailLine('Account / profile', accountUpdate),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationUpdate(Map<String, dynamic> notification) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification['title']?.toString() ?? 'Update',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF18222D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notification['message']?.toString() ?? '-',
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTimestamp(notification['timestamp']),
            style: TextStyle(
              color: role.accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: role.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: role.accentColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87, height: 1.4),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 30, color: role.accentColor),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _visibleAlerts() {
    final items = List<Map<String, dynamic>>.from(alerts)
      ..sort((left, right) {
        final severityCompare = _impactLevel(
          right,
        ).compareTo(_impactLevel(left));
        if (severityCompare != 0) {
          return severityCompare;
        }
        return AppRepository.parseTimestamp(
          right['timestamp'],
        ).compareTo(AppRepository.parseTimestamp(left['timestamp']));
      });

    return items
        .where((alert) {
          final level = _impactLevel(alert);
          switch (role) {
            case DashboardRole.ambulance:
              return level >= 4;
            case DashboardRole.insurance:
              return level >= 1;
          }
        })
        .toList(growable: false);
  }

  bool _matchesRoleNotification(Map<String, dynamic> notification) {
    final audience = notification['audience']?.toString().toLowerCase() ?? '';
    if (audience == 'all') {
      return true;
    }

    switch (role) {
      case DashboardRole.ambulance:
        return audience == 'hospital' || audience == 'emergency_contact';
      case DashboardRole.insurance:
        return true;
    }
  }

  int _impactLevel(Map<String, dynamic> alert) {
    final value = alert['impact_level'];
    if (value is num) {
      return value.toInt().clamp(1, 5);
    }
    return (int.tryParse(value?.toString() ?? '') ?? 1).clamp(1, 5);
  }

  String _feedSummary() {
    switch (role) {
      case DashboardRole.ambulance:
        return 'Hospital only receives Level 4 and Level 5 cases.';
      case DashboardRole.insurance:
        return 'Insurance receives every impact level and all related case updates.';
    }
  }

  String _summaryForRole(Map<String, dynamic> alert) {
    switch (role) {
      case DashboardRole.ambulance:
        final patients = alert['number_of_people']?.toString();
        final patientStatus = alert['patient_status']?.toString();
        final responderNote = alert['responder_note']?.toString();
        final eta = alert['ambulance_eta_minutes']?.toString();
        final unit = alert['ambulance_unit']?.toString();
        final contact = alert['ambulance_contact']?.toString();
        final team = alert['ambulance_team_size']?.toString();
        final responseNote = alert['ambulance_response_note']?.toString();
        if ((patients ?? '').isNotEmpty ||
            (patientStatus ?? '').isNotEmpty ||
            (responderNote ?? '').isNotEmpty ||
            (eta ?? '').isNotEmpty ||
            (unit ?? '').isNotEmpty ||
            (contact ?? '').isNotEmpty ||
            (team ?? '').isNotEmpty ||
            (responseNote ?? '').isNotEmpty) {
          return [
            if ((eta ?? '').isNotEmpty) 'ETA $eta min',
            if ((unit ?? '').isNotEmpty) 'Unit $unit',
            if ((contact ?? '').isNotEmpty) 'Contact $contact',
            if ((team ?? '').isNotEmpty) 'Team $team',
            if ((patients ?? '').isNotEmpty) '$patients patient(s)',
            if ((patientStatus ?? '').isNotEmpty) patientStatus,
            if ((responderNote ?? '').isNotEmpty) responderNote,
            if ((responseNote ?? '').isNotEmpty &&
                responseNote != responderNote)
              responseNote,
          ].join(' - ');
        }
        return alert['driver_response_summary']?.toString() ??
            alert['recommended_response']?.toString() ??
            AppRepository.severityExplanation(_impactLevel(alert));
      case DashboardRole.insurance:
        return [
          AppRepository.severityLabel(_impactLevel(alert)),
          alert['insurance_status']?.toString() ?? 'Pending review',
          alert['repair_condition']?.toString() ??
              alert['patient_status']?.toString() ??
              'Claim details syncing',
        ].join(' - ');
    }
  }

  String _actionText(Map<String, dynamic> alert) {
    switch (role) {
      case DashboardRole.ambulance:
        return alert['hospital_feed_status']?.toString() ??
            alert['status']?.toString() ??
            'Waiting for hospital team review.';
      case DashboardRole.insurance:
        return alert['insurance_status']?.toString() ??
            'Pending insurance review.';
    }
  }

  String? _accountUpdateLine(Map<String, dynamic> alert) {
    final assignedDriver =
        alert['assigned_driver_name']?.toString().trim() ?? '';
    final dispatchStatus =
        alert['driver_dispatch_status']?.toString().trim() ?? '';
    final eta = alert['ambulance_eta_minutes']?.toString().trim() ?? '';
    final unit = alert['ambulance_unit']?.toString().trim() ?? '';
    final technicianLocation =
        alert['technician_location']?.toString().trim() ?? '';
    final hospitalName = alert['hospital_name']?.toString().trim() ?? '';

    final values = <String>[
      if (assignedDriver.isNotEmpty) 'Responder: $assignedDriver',
      if (dispatchStatus.isNotEmpty) 'Dispatch: $dispatchStatus',
      if (eta.isNotEmpty) 'ETA: $eta min',
      if (unit.isNotEmpty) 'Unit: $unit',
      if (technicianLocation.isNotEmpty) 'Location: $technicianLocation',
      if (hospitalName.isNotEmpty) 'Hospital: $hospitalName',
    ];

    if (values.isEmpty) {
      return null;
    }
    return values.join(' - ');
  }

  String _driverName(Map<String, dynamic> alert) {
    return alert['driver']?.toString().trim().isNotEmpty == true
        ? alert['driver'].toString().trim()
        : 'EV Driver';
  }

  String _vehicleLabel(Map<String, dynamic> alert) {
    return alert['vehicle']?.toString().trim().isNotEmpty == true
        ? alert['vehicle'].toString().trim()
        : 'EV Vehicle';
  }

  String _statusText(Map<String, dynamic> alert) {
    return alert['status']?.toString().trim().isNotEmpty == true
        ? alert['status'].toString().trim()
        : 'Logged';
  }

  String _locationText(Map<String, dynamic> alert) {
    final locationName = alert['location_name']?.toString().trim() ?? '';
    final roadName = alert['road_name']?.toString().trim() ?? '';
    if (locationName.isEmpty && roadName.isEmpty) {
      return 'Unknown location';
    }
    if (locationName.isEmpty) {
      return roadName;
    }
    if (roadName.isEmpty) {
      return locationName;
    }
    return '$locationName - $roadName';
  }

  String _alertId(Map<String, dynamic> alert) {
    return alert['alert_id']?.toString() ?? alert['id']?.toString() ?? '';
  }

  String _formatTimestamp(Object? value) {
    final date = AppRepository.parseTimestamp(value).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
