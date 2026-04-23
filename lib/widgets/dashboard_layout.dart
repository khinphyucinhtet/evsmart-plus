import 'package:flutter/material.dart';

enum DashboardRole { ambulance, insurance }

extension DashboardRolePresentation on DashboardRole {
  String get label {
    switch (this) {
      case DashboardRole.ambulance:
        return 'Hospital Dashboard';
      case DashboardRole.insurance:
        return 'Insurance Dashboard';
    }
  }

  String get description {
    switch (this) {
      case DashboardRole.ambulance:
        return 'Level 4 and Level 5 impact notifications for hospital teams.';
      case DashboardRole.insurance:
        return 'Level 1 to Level 5 impact notifications for insurance review.';
    }
  }

  Color get accentColor {
    switch (this) {
      case DashboardRole.ambulance:
        return const Color(0xFF198754);
      case DashboardRole.insurance:
        return const Color(0xFFB45309);
    }
  }

  Color get sidebarColor {
    switch (this) {
      case DashboardRole.ambulance:
        return const Color(0xFF0E4B2A);
      case DashboardRole.insurance:
        return const Color(0xFF7C2D12);
    }
  }
}

class DashboardLayout extends StatelessWidget {
  const DashboardLayout({
    super.key,
    required this.activeRole,
    required this.onRoleSelected,
    required this.liveTimestamp,
    required this.selectedRangeLabel,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onRefresh,
    required this.cleanupDays,
    required this.onCleanupDaysChanged,
    required this.onClearLogs,
    required this.onDeleteSelected,
    required this.selectedCount,
    required this.logCount,
    required this.isClearing,
    required this.isDeleting,
    required this.notifications,
    required this.child,
  });

  final DashboardRole activeRole;
  final ValueChanged<DashboardRole> onRoleSelected;
  final DateTime liveTimestamp;
  final String selectedRangeLabel;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final VoidCallback onRefresh;
  final int cleanupDays;
  final ValueChanged<int?> onCleanupDaysChanged;
  final VoidCallback onClearLogs;
  final VoidCallback onDeleteSelected;
  final int selectedCount;
  final int logCount;
  final bool isClearing;
  final bool isDeleting;
  final List<Map<String, dynamic>> notifications;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;

            return Row(
              children: [
                _buildSidebar(isWide),
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActionBar(),
                              const SizedBox(height: 20),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isWide) {
    return Container(
      width: isWide ? 260 : 92,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      color: activeRole.sidebarColor,
      child: Column(
        crossAxisAlignment: isWide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: Colors.white,
            ),
          ),
          if (isWide) ...[
            const SizedBox(height: 14),
            const Text(
              'EVSmart+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Simple live dashboard menu',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
            ),
          ],
          const SizedBox(height: 28),
          ...DashboardRole.values.map((role) {
            final selected = role == activeRole;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: selected
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => onRoleSelected(role),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 14 : 10,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: isWide
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(_roleIcon(role), color: Colors.white),
                        if (isWide) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              role.label.replaceAll(' Dashboard', ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          if (isWide)
            Text(
              activeRole.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeRole.label,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: activeRole.accentColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                activeRole.description,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statusChip(Icons.list_alt_rounded, '$logCount live logs'),
              _statusChip(
                Icons.notifications_active_outlined,
                '${notifications.length} updates',
              ),
              _statusChip(
                Icons.schedule_rounded,
                _formatTimestamp(liveTimestamp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            avatar: Icon(
              Icons.date_range_rounded,
              color: activeRole.accentColor,
            ),
            label: Text(selectedRangeLabel),
            onPressed: onPickDateRange,
            backgroundColor: activeRole.accentColor.withValues(alpha: 0.08),
          ),
          TextButton(
            onPressed: onClearDateRange,
            child: const Text('Reset range'),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: cleanupDays,
              decoration: const InputDecoration(
                labelText: 'Clear older than',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 2, child: Text('2 days')),
                DropdownMenuItem(value: 5, child: Text('5 days')),
              ],
              onChanged: onCleanupDaysChanged,
            ),
          ),
          FilledButton.icon(
            onPressed: isClearing ? null : onClearLogs,
            style: FilledButton.styleFrom(
              backgroundColor: activeRole.accentColor,
              foregroundColor: Colors.white,
            ),
            icon: isClearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_delete_outlined),
            label: const Text('Clear logs'),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 || isDeleting
                ? null
                : onDeleteSelected,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            icon: isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text('Delete selected ($selectedCount)'),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: activeRole.accentColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  IconData _roleIcon(DashboardRole role) {
    switch (role) {
      case DashboardRole.ambulance:
        return Icons.local_hospital_rounded;
      case DashboardRole.insurance:
        return Icons.shield_outlined;
    }
  }

  String _formatTimestamp(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
