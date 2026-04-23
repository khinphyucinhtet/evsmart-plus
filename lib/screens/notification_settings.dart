import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _enabled = value;
    });
    await NotificationService.setNotificationsEnabled(value);
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

  @override
  Widget build(BuildContext context) {
    final unsupported =
        kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Turn on device notifications for Level 4 and Level 5 alerts, hospital dispatch requests, and ambulance report updates.',
                        style: TextStyle(color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: _enabled && !unsupported,
                        onChanged: unsupported ? null : _toggleNotifications,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable push notifications'),
                        subtitle: Text(
                          unsupported
                              ? 'Browser notifications are not configured in this build.'
                              : 'Recommended for EV users, ambulance drivers, and hospital staff.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How It Works',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '1. EV user sends manual SOS or impact alert.\n2. Hospital and ambulance devices receive alert updates.\n3. Driver acceptance, arrival, and report submission sync back to Firebase.\n4. This device shows local notifications when updates arrive.',
                        style: TextStyle(color: Colors.black54, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
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
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Request permission again'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
