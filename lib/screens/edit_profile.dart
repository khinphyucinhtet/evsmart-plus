import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ImagePicker picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final plateController = TextEditingController();
  final vinController = TextEditingController();
  final batteryCapacityController = TextEditingController();

  bool _isSaving = false;
  String selectedBrand = 'Select Brand';
  String selectedModel = 'Select Model';
  String encodedImage = '';
  String? profileImageBase64;

  final List<String> brands = [
    'Select Brand',
    'AION',
    'Audi',
    'BMW',
    'BYD',
    'Bentley',
    'Chery',
    'Citroen',
    'Deepal',
    'Dongfeng',
    'Fiat',
    'Ford',
    'Foton',
    'GWM',
    'Higer',
    'Honda',
    'Hyundai',
    'IM',
    'JAC',
    'Kia',
    'Leapmotor',
    'Lexus',
    'MG',
    'Mercedes-Benz',
    'Mitsubishi',
    'Neta',
    'Nissan',
    'Proton',
    'Tesla',
    'Toyota',
    'Xpeng',
    'Zeekr',
  ];

  final Map<String, List<String>> modelMap = {
    'AION': ['Select Model', 'Aion Y Plus', 'Aion ES EV', 'Aion V'],
    'Audi': ['Select Model', 'Q4 e-tron', 'Q8 e-tron', 'SQ8 e-tron'],
    'BMW': ['Select Model', 'i4', 'iX', 'i7'],
    'BYD': ['Select Model', 'Atto 3', 'Dolphin', 'Seal'],
    'Bentley': [
      'Select Model',
      'Bentayga Hybrid',
      'Flying Spur Hybrid',
      'Continental GT Hybrid',
    ],
    'Chery': ['Select Model', 'EQ1', 'EQ5', 'Little Ant'],
    'Citroen': ['Select Model', 'e-C4', 'e-Berlingo', 'Ami EV'],
    'Deepal': ['Select Model', 'SL03', 'S7', 'G318 EV'],
    'Dongfeng': ['Select Model', 'Nammi 01', 'E70', 'EX1'],
    'Fiat': ['Select Model', '500e', 'E-Ulysse', 'E-Doblo'],
    'Ford': ['Select Model', 'Mustang Mach-E', 'F-150 Lightning', 'E-Transit'],
    'Foton': ['Select Model', 'iBlue EV', 'Toano EV', 'Aumark EV'],
    'GWM': ['Select Model', 'Ora Good Cat', 'Ora Funky Cat', 'Tank 500 EV'],
    'Higer': ['Select Model', 'KLQ EV Bus', 'Azure EV', 'Urban EV'],
    'Honda': ['Select Model', 'e:NS1', 'e:NP1', 'Honda e'],
    'Hyundai': ['Select Model', 'Ioniq 5', 'Ioniq 6', 'Kona Electric'],
    'IM': ['Select Model', 'LS7', 'L7', 'LS6'],
    'JAC': ['Select Model', 'E-J7', 'iEV7S', 'iEV6E'],
    'Kia': ['Select Model', 'EV6', 'EV9', 'Niro EV'],
    'Leapmotor': ['Select Model', 'C11', 'T03', 'C01'],
    'Lexus': ['Select Model', 'RZ 450e', 'UX 300e', 'LF-ZC'],
    'MG': ['Select Model', 'MG4 EV', 'ZS EV', 'Marvel R'],
    'Mercedes-Benz': ['Select Model', 'EQS', 'EQE', 'EQA'],
    'Mitsubishi': ['Select Model', 'i-MiEV', 'Outlander PHEV', 'Minicab EV'],
    'Neta': ['Select Model', 'V', 'X', 'S'],
    'Nissan': ['Select Model', 'Leaf', 'Ariya', 'Sakura'],
    'Proton': ['Select Model', 'e.MAS 7', 'Iriz EV', 'Persona EV'],
    'Tesla': ['Select Model', 'Model 3', 'Model Y', 'Model S'],
    'Toyota': ['Select Model', 'bZ4X', 'C+pod', 'Proace EV'],
    'Xpeng': ['Select Model', 'P7', 'G9', 'G6'],
    'Zeekr': ['Select Model', '001', 'X', '009'],
  };

  List<String> currentModels = ['Select Model'];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    idController.dispose();
    phoneController.dispose();
    emailController.dispose();
    usernameController.dispose();
    plateController.dispose();
    vinController.dispose();
    batteryCapacityController.dispose();
    super.dispose();
  }

  ImageProvider _buildProfileImage() {
    try {
      if (profileImageBase64 != null &&
          profileImageBase64!.isNotEmpty &&
          profileImageBase64 != 'null') {
        return MemoryImage(
          base64Decode(
            profileImageBase64!
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .trim(),
          ),
        );
      }
    } catch (_) {}
    return const AssetImage('assets/images/ic_user_profile.png');
  }

  String _safeBrand(String? value) {
    final brand = value?.trim();
    return brands.contains(brand) ? brand! : brands.first;
  }

  String _safeModel(String brand, String? value) {
    final models = modelMap[brand] ?? const ['Select Model'];
    final model = value?.trim();
    return models.contains(model) ? model! : models.first;
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final profile = await AppRepository.getCurrentUserProfile() ??
        <String, dynamic>{};
    final vehicle = await AppRepository.getCurrentVehicle() ??
        <String, dynamic>{};

    if (!mounted) {
      return;
    }

    final resolvedBrand = _safeBrand(
      vehicle['brand']?.toString() ?? profile['brand']?.toString(),
    );
    final resolvedModel = _safeModel(
      resolvedBrand,
      vehicle['model']?.toString() ??
          profile['vehicle_model']?.toString() ??
          profile['model']?.toString(),
    );

    setState(() {
      fullNameController.text = profile['fullName']?.toString() ?? '';
      idController.text = profile['idNumber']?.toString() ?? '';
      phoneController.text = profile['phone']?.toString() ?? '';
      emailController.text = profile['email']?.toString() ?? user.email ?? '';
      usernameController.text = profile['username']?.toString() ?? '';
      plateController.text =
          vehicle['plate']?.toString() ??
          profile['vehicle_plate']?.toString() ??
          profile['plate']?.toString() ??
          '';
      vinController.text = vehicle['vin']?.toString() ?? profile['vin']?.toString() ?? '';
      batteryCapacityController.text =
          vehicle['battery_capacity']?.toString() ??
          profile['battery_capacity']?.toString() ??
          '';
      selectedBrand = resolvedBrand;
      currentModels = modelMap[resolvedBrand] ?? ['Select Model'];
      selectedModel = resolvedModel;
      profileImageBase64 = profile['profileImage']?.toString();
    });
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    setState(() {
      encodedImage = base64Encode(bytes);
      profileImageBase64 = encodedImage;
    });
  }

  Future<void> updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showMessage('Please sign in again to update your profile.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final uid = user.uid;
    final profileData = <String, dynamic>{
      'uid': uid,
      'fullName': fullNameController.text.trim(),
      'idNumber': idController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'username': usernameController.text.trim(),
      'brand': selectedBrand,
      'model': selectedModel,
      'vehicle_model': selectedModel,
      'plate': plateController.text.trim(),
      'vehicle_plate': plateController.text.trim(),
      'vin': vinController.text.trim(),
      'battery_capacity': batteryCapacityController.text.trim(),
      if (encodedImage.isNotEmpty) 'profileImage': encodedImage,
    };

    final vehicleData = <String, dynamic>{
      'vehicle_id': uid,
      'user_id': uid,
      'brand': selectedBrand,
      'model': selectedModel,
      'plate': plateController.text.trim(),
      'vin': vinController.text.trim(),
      'battery_capacity': batteryCapacityController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final database = FirebaseDatabase.instanceFor(
        app: FirebaseAuth.instance.app,
        databaseURL: AppRepository.databaseUrl,
      );

      await Future.wait([
        database.ref('users').child(uid).update(profileData),
        AppRepository.legacyUsersRef.child(uid).update(profileData),
        AppRepository.upsertVehicle(uid, vehicleData),
      ]);

      await AppRepository.pushDashboardNotification(
        audience: 'all',
        type: 'Profile',
        title: 'Driver account updated',
        message:
            '${fullNameController.text.trim()} updated vehicle and contact details.',
        alertId: 'profile_$uid',
      );

      if (!mounted) {
        return;
      }

      showMessage('Profile updated successfully');
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showMessage('Unable to update profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _buildProfileImage(),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: pickImage,
                  child: const Text(
                    'Upload Picture',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                buildField('Full Name', fullNameController),
                buildField('ID Number', idController),
                buildField(
                  'Phone Number',
                  phoneController,
                  keyboardType: TextInputType.phone,
                ),
                buildField(
                  'Email Address',
                  emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final required = _requiredValidator(value, 'Email');
                    if (required != null) {
                      return required;
                    }
                    final email = value!.trim();
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                buildField('Username', usernameController),
                const SizedBox(height: 10),
                const Text(
                  'My Vehicles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                buildBrandDropdown(),
                const SizedBox(height: 12),
                buildModelDropdown(),
                buildField('Plate Number', plateController),
                buildField('VIN (Optional)', vinController, required: false),
                buildField(
                  'Battery Capacity (kWh)',
                  batteryCapacityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    onPressed: _isSaving ? null : updateProfile,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Changes',
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

  Widget buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
    String? Function(String?)? validator,
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
            validator: validator ??
                (required ? (value) => _requiredValidator(value, label) : null),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget buildBrandDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: brands.contains(selectedBrand) ? selectedBrand : brands.first,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: brands
          .map((brand) => DropdownMenuItem(value: brand, child: Text(brand)))
          .toList(),
      validator: (value) {
        if (value == null || value == 'Select Brand') {
          return 'Select a vehicle brand';
        }
        return null;
      },
      onChanged: (value) {
        final safeBrand = _safeBrand(value);
        setState(() {
          selectedBrand = safeBrand;
          currentModels = modelMap[safeBrand] ?? ['Select Model'];
          selectedModel = currentModels.first;
        });
      },
    );
  }

  Widget buildModelDropdown() {
    final safeModels = currentModels.isEmpty ? ['Select Model'] : currentModels;
    final safeValue = safeModels.contains(selectedModel)
        ? selectedModel
        : safeModels.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: safeModels
          .map((model) => DropdownMenuItem(value: model, child: Text(model)))
          .toList(),
      validator: (value) {
        if (value == null || value == 'Select Model') {
          return 'Select a vehicle model';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          selectedModel = _safeModel(selectedBrand, value);
        });
      },
    );
  }
}


