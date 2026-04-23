import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'ambulance_driver_edit_profile.dart';
import 'ambulance_profile.dart';
import 'change_password.dart';
import 'edit_profile.dart';
import 'language.dart';
import 'login_page.dart';
import 'notification_settings.dart';
import 'privacy_policy.dart';
import 'report_problem.dart';
import 'support.dart';
import 'terms.dart';
import 'view_profile.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool showProfile = false;
  bool showHelp = false;
  bool showSettings = false;

  String userName = 'User';
  String role = '';
  String? profileImageBase64;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final profile = await AppRepository.getCurrentUserProfile() ?? <String, dynamic>{};
    final normalizedRole = profile['role']?.toString() ?? '';
    Map<String, dynamic>? roleProfile;

    if (_isAmbulanceRole(normalizedRole)) {
      roleProfile = await AppRepository.getProfileByPath(
        AppRepository.ambulanceProfilesRef,
        user.uid,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      role = normalizedRole;
      userName = _resolveUserName(profile, normalizedRole, roleProfile);
      profileImageBase64 =
          roleProfile?['profileImage']?.toString() ??
          roleProfile?['profile_image']?.toString() ??
          profile['profileImage']?.toString();
    });
  }

  String _resolveUserName(
    Map<String, dynamic> profile,
    String normalizedRole,
    Map<String, dynamic>? roleProfile,
  ) {
    if (_isAmbulanceRole(normalizedRole)) {
      return roleProfile?['driver_name']?.toString() ??
          roleProfile?['ambulance_name']?.toString() ??
          profile['fullName']?.toString() ??
          'Ambulance User';
    }

    return profile['fullName']?.toString() ??
        profile['username']?.toString() ??
        'EV Driver';
  }

  bool _isAmbulanceRole(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('ambulance') || normalized.contains('hospital');
  }

  ImageProvider _buildProfileImage() {
    try {
      if (profileImageBase64 != null &&
          profileImageBase64!.isNotEmpty &&
          profileImageBase64 != 'null') {
        final cleaned = profileImageBase64!
            .replaceAll('\n', '')
            .replaceAll('\r', '')
            .trim();
        return MemoryImage(base64Decode(cleaned));
      }
    } catch (_) {}

    return const AssetImage('assets/images/ic_user_profile.png');
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final uid = user.uid;
    await Future.wait([
      AppRepository.usersRef.child(uid).remove(),
      AppRepository.legacyUsersRef.child(uid).remove(),
      AppRepository.vehiclesRef.child(uid).remove(),
      AppRepository.ambulanceProfilesRef.child(uid).remove(),
      AppRepository.technicianProfilesRef.child(uid).remove(),
    ]);
    await user.delete();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _logoutUser() {
    _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildProfileViewPage() {
    if (_isAmbulanceRole(role)) {
      return const AmbulanceProfilePage();
    }
    return const ViewProfilePage();
  }

  Widget _buildEditProfilePage() {
    if (_isAmbulanceRole(role)) {
      return const AmbulanceDriverEditProfilePage();
    }
    return const EditProfilePage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.white.withValues(alpha: 0.6)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 300,
              height: double.infinity,
              color: Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _buildProfileImage(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (role.isNotEmpty)
                                Text(
                                  role,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    _buildSectionTitle('Profile', () {
                      setState(() {
                        showProfile = !showProfile;
                      });
                    }),
                    if (showProfile) ...[
                      _buildItem('View Profile', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _buildProfileViewPage(),
                          ),
                        ).then((_) => _loadUserData());
                      }),
                      _buildItem('Edit Profile', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _buildEditProfilePage(),
                          ),
                        ).then((_) => _loadUserData());
                      }),
                      _buildItem('Change Password', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        );
                      }),
                      _buildItem(
                        'Delete Account',
                        _showDeleteDialog,
                        color: Colors.red,
                      ),
                      _buildItem('Logout', _logoutUser),
                    ],
                    _buildSectionTitle('Help And Support', () {
                      setState(() {
                        showHelp = !showHelp;
                      });
                    }),
                    if (showHelp) ...[
                      _buildItem('Support', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SupportPage()),
                        );
                      }),
                      _buildItem('Report Problem', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportProblemPage(),
                          ),
                        );
                      }),
                      _buildItem('Terms And Conditions', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsPage()),
                        );
                      }),
                    ],
                    _buildSectionTitle('Settings And Privacy', () {
                      setState(() {
                        showSettings = !showSettings;
                      });
                    }),
                    if (showSettings) ...[
                      _buildItem('Notification Settings', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsPage(),
                          ),
                        );
                      }),
                      _buildItem('Language', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LanguagePage()),
                        );
                      }),
                      _buildItem('Privacy Policy', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyPage(),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          '$title ▼',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildItem(
    String title,
    VoidCallback onTap, {
    Color color = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Text(title, style: TextStyle(fontSize: 15, color: color)),
      ),
    );
  }
}
