import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'edit_profile.dart';

class ViewProfilePage extends StatefulWidget {
  const ViewProfilePage({super.key});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final fullNameController = TextEditingController();
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();

  String brand = '';
  String model = '';
  String plate = '';
  String vin = '';
  String? profileImageBase64;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    final profile = await AppRepository.getCurrentUserProfile();
    final vehicleSnapshot = await AppRepository.vehiclesRef
        .child(FirebaseAuth.instance.currentUser!.uid)
        .get();
    final vehicle = vehicleSnapshot.value is Map
        ? Map<String, dynamic>.from(vehicleSnapshot.value as Map)
        : <String, dynamic>{};

    if (!mounted || profile == null) {
      return;
    }

    setState(() {
      fullNameController.text = profile['fullName']?.toString() ?? '';
      idController.text = profile['idNumber']?.toString() ?? '';
      phoneController.text = profile['phone']?.toString() ?? '';
      emailController.text = profile['email']?.toString() ?? '';
      usernameController.text = profile['username']?.toString() ?? '';
      brand =
          vehicle['brand']?.toString() ?? profile['brand']?.toString() ?? '';
      model =
          vehicle['model']?.toString() ?? profile['model']?.toString() ?? '';
      plate =
          vehicle['plate']?.toString() ?? profile['plate']?.toString() ?? '';
      vin = vehicle['vin']?.toString() ?? profile['vin']?.toString() ?? '';
      profileImageBase64 = profile['profileImage']?.toString();
    });
  }

  Widget buildDisabledField(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget buildVehicleBox(String value) {
    return Container(
      height: 50,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value, style: const TextStyle(color: Colors.black)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Container(
                height: 72,
                alignment: Alignment.center,
                child: const Text(
                  'User Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            profileImageBase64 != null &&
                                profileImageBase64!.isNotEmpty
                            ? MemoryImage(base64Decode(profileImageBase64!))
                            : const AssetImage(
                                    'assets/images/ic_user_profile.png',
                                  )
                                  as ImageProvider,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Full Name', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildDisabledField(fullNameController, 'Eg: Pinky'),
                    const SizedBox(height: 15),
                    const Text('ID Number', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildDisabledField(idController, 'Eg: 1234567890'),
                    const SizedBox(height: 15),
                    const Text('Phone Number', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildDisabledField(
                      phoneController,
                      'Eg: 0123456789',
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 15),
                    const Text('Email Address', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildDisabledField(
                      emailController,
                      'Eg: pinky@gmail.com',
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 15),
                    const Text('Username', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildDisabledField(usernameController, 'Eg: pinky00'),
                    const SizedBox(height: 24),
                    const Text(
                      'My Vehicles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Brand Name', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildVehicleBox(brand),
                    const SizedBox(height: 15),
                    const Text('Model', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildVehicleBox(model),
                    const SizedBox(height: 15),
                    const Text('Plate Number', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildVehicleBox(plate),
                    const SizedBox(height: 15),
                    const Text('VIN', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 6),
                    buildVehicleBox(vin),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfilePage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
