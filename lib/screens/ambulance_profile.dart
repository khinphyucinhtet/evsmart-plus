import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'ambulance_driver_edit_profile.dart';
import 'menu.dart';

class AmbulanceProfilePage extends StatefulWidget {
  const AmbulanceProfilePage({super.key});

  @override
  State<AmbulanceProfilePage> createState() => _AmbulanceProfilePageState();
}

class _AmbulanceProfilePageState extends State<AmbulanceProfilePage> {
  Map<String, dynamic> profile = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final data = await AppRepository.getProfileByPath(
      AppRepository.ambulanceProfilesRef,
      uid,
    );

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      profile = data;
    });
  }

  ImageProvider _buildProfileImage() {
    final raw =
        profile['profileImage']?.toString() ?? profile['profile_image']?.toString();

    try {
      if (raw != null && raw.isNotEmpty && raw != 'null') {
        return MemoryImage(
          base64Decode(raw.replaceAll('\n', '').replaceAll('\r', '').trim()),
        );
      }
    } catch (_) {}

    return const AssetImage('assets/images/ic_user_profile.png');
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuPage()),
            );
          },
        ),
        title: const Text(
          'Ambulance Profile',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AmbulanceDriverEditProfilePage(),
                ),
              );
              _loadProfile();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _buildProfileImage(),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Ambulance and driver details used for emergency dispatch.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 18),
                _infoRow(
                  'Ambulance Name',
                  profile['ambulance_name']?.toString() ?? '-',
                ),
                _infoRow(
                  'Hospital Name',
                  profile['hospital_name']?.toString() ?? '-',
                ),
                _infoRow(
                  'Vehicle Number',
                  profile['vehicle_number']?.toString() ?? '-',
                ),
                _infoRow(
                  'Driver Name',
                  profile['driver_name']?.toString() ?? '-',
                ),
                _infoRow(
                  'Qualification',
                  profile['qualification']?.toString() ?? '-',
                ),
                _infoRow(
                  'Contact Number',
                  profile['contact_number']?.toString() ?? '-',
                ),
                _infoRow(
                  'Current Location',
                  profile['current_location']?.toString() ?? '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
