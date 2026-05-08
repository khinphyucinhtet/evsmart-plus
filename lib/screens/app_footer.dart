import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.activeColor = const Color(0xFF2E7D32),
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;

  static const List<_FooterTabData> _tabs = <_FooterTabData>[
    _FooterTabData(icon: Icons.home, label: 'Home'),
    _FooterTabData(icon: Icons.ev_station, label: 'Charge'),
    _FooterTabData(icon: Icons.warning, label: 'Alert'),
    _FooterTabData(icon: Icons.notifications, label: 'Noti'),
    _FooterTabData(icon: Icons.card_giftcard, label: 'Rewards'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;

        return Container(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset + 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
          ),
          child: Row(
            children: List<Widget>.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isActive = currentIndex == index;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: isActive
                        ? activeColor.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(index),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 8 : 9,
                          horizontal: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: compact ? 22 : 24,
                              color: isActive ? activeColor : Colors.grey,
                            ),
                            SizedBox(height: compact ? 3 : 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: compact ? 11 : 12,
                                  color: isActive ? activeColor : Colors.grey,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _FooterTabData {
  const _FooterTabData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
