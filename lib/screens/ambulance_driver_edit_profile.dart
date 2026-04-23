import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_repository.dart';

class AmbulanceDriverEditProfilePage extends StatefulWidget {
  const AmbulanceDriverEditProfilePage({super.key});

  @override
  State<AmbulanceDriverEditProfilePage> createState() =>
      _AmbulanceDriverEditProfilePageState();
}

class _AmbulanceDriverEditProfilePageState
    extends State<AmbulanceDriverEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final ambulanceNameController = TextEditingController();
  final hospitalNameController = TextEditingController();
  final vehicleNumberController = TextEditingController();
  final driverNameController = TextEditingController();
  final qualificationController = TextEditingController();
  final contactNumberController = TextEditingController();
  final currentLocationController = TextEditingController();

  bool _isSaving = false;
  String _encodedImage = '';
  String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    ambulanceNameController.dispose();
    hospitalNameController.dispose();
    vehicleNumberController.dispose();
    driverNameController.dispose();
    qualificationController.dispose();
    contactNumberController.dispose();
    currentLocationController.dispose();
    super.dispose();
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
      ambulanceNameController.text = data['ambulance_name']?.toString() ?? '';
      hospitalNameController.text = data['hospital_name']?.toString() ?? '';
      vehicleNumberController.text = data['vehicle_number']?.toString() ?? '';
      driverNameController.text = data['driver_name']?.toString() ?? '';
      qualificationController.text = data['qualification']?.toString() ?? '';
      contactNumberController.text = data['contact_number']?.toString() ?? '';
      currentLocationController.text = data['current_location']?.toString() ?? '';
      _profileImageBase64 =
          data['profileImage']?.toString() ?? data['profile_image']?.toString();
    });
  }

  ImageProvider _buildProfileImage() {
    try {
      if (_profileImageBase64 != null &&
          _profileImageBase64!.isNotEmpty &&
          _profileImageBase64 != 'null') {
        return MemoryImage(
          base64Decode(
            _profileImageBase64!
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .trim(),
          ),
        );
      }
    } catch (_) {}

    return const AssetImage('assets/images/ic_user_profile.png');
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    setState(() {
      _encodedImage = base64Encode(bytes);
      _profileImageBase64 = _encodedImage;
    });
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await AppRepository.upsertAmbulanceProfile(uid, {
      'uid': uid,
      'ambulance_name': ambulanceNameController.text.trim(),
      'hospital_name': hospitalNameController.text.trim(),
      'vehicle_number': vehicleNumberController.text.trim(),
      'driver_name': driverNameController.text.trim(),
      'qualification': qualificationController.text.trim(),
      'contact_number': contactNumberController.text.trim(),
      'current_location': currentLocationController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
      if (_encodedImage.isNotEmpty) 'profileImage': _encodedImage,
      if (_encodedImage.isNotEmpty) 'profile_image': _encodedImage,
    });

    await AppRepository.pushDashboardNotification(
      audience: 'all',
      type: 'Profile',
      title: 'Hospital profile updated',
      message:
          '${hospitalNameController.text.trim()} updated ambulance contact details.',
      alertId: 'profile_$uid',
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ambulance profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Edit Ambulance Profile',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _buildProfileImage(),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: _pickImage,
                  child: const Text(
                    'Upload Picture',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                _field('Ambulance Name', ambulanceNameController),
                _field('Hospital Name', hospitalNameController),
                _field('Vehicle Number', vehicleNumberController),
                _field('Driver Name', driverNameController),
                _field('Qualification', qualificationController),
                _field(
                  'Contact Number',
                  contactNumberController,
                  keyboardType: TextInputType.phone,
                ),
                _field('Current Location', currentLocationController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Profile',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
