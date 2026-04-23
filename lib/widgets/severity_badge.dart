import 'package:flutter/material.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  factory SeverityBadge.fromSeverity(
    String severity, {
    Key? key,
  }) {
    final normalized = severity.toLowerCase().trim();
    switch (normalized) {
      case 'green':
      case 'low':
      case 'level 1':
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: Colors.green.withValues(alpha: 0.14),
          foregroundColor: Colors.green.shade800,
        );
      case 'yellow':
      case 'medium':
      case 'level 2':
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: Colors.yellow.shade100,
          foregroundColor: Colors.amber.shade900,
        );
      case 'orange':
      case 'level 3':
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: Colors.orange.withValues(alpha: 0.16),
          foregroundColor: Colors.orange.shade900,
        );
      case 'red':
      case 'high':
      case 'level 4':
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: Colors.red.withValues(alpha: 0.14),
          foregroundColor: Colors.red.shade800,
        );
      case 'critical':
      case 'level 5':
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: const Color(0xFFFEE2E2),
          foregroundColor: const Color(0xFF991B1B),
        );
      default:
        return SeverityBadge(
          key: key,
          label: severity,
          backgroundColor: Colors.blueGrey.withValues(alpha: 0.12),
          foregroundColor: Colors.blueGrey.shade800,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor ?? Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
