import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'register_success.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  String selectedRole = 'Select User Type';
  bool isLoading = false;

  final List<String> roles = const [
    'Select User Type',
    'EV Driver',
    'Ambulance User',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              buildLabel('Full Name'),
              buildField(fullNameController, 'Eg: Pinky'),
              buildLabel('ID Number'),
              buildField(idController, 'Eg: 1234567890'),
              buildLabel('Phone Number'),
              buildField(
                phoneController,
                'Eg: 0123456789',
                inputType: TextInputType.phone,
              ),
              buildLabel('Email Address'),
              buildField(
                emailController,
                'Eg: pinky@gmail.com',
                inputType: TextInputType.emailAddress,
              ),
              buildLabel('Username'),
              buildField(usernameController, 'Eg: pinky00'),
              buildLabel('Password'),
              buildField(passwordController, 'Enter password', obscure: true),
              buildLabel('Confirm Password'),
              buildField(
                confirmPasswordController,
                'Re-enter password',
                obscure: true,
              ),
              const SizedBox(height: 10),
              buildLabel('Select Your User Type'),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: roles
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E7D32),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: isLoading ? null : registerUser,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 15),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
      ),
    );
  }

  Widget buildField(
    TextEditingController controller,
    String hint, {
    bool obscure = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: inputType,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> registerUser() async {
    final fullName = fullNameController.text.trim();
    final idNumber = idController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if ([
      fullName,
      idNumber,
      phone,
      email,
      username,
      password,
      confirmPassword,
    ].any((value) => value.isEmpty)) {
      showMessage('Please fill all fields');
      return;
    }
    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      showMessage('Passwords do not match');
      return;
    }
    if (selectedRole == 'Select User Type') {
      showMessage('Please select user type');
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await mAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      await AppRepository.upsertUserProfile(uid, {
        'uid': uid,
        'fullName': fullName,
        'idNumber': idNumber,
        'phone': phone,
        'email': email,
        'username': username,
        'role': selectedRole,
        'vehicle_id': uid,
      });

      await AppRepository.upsertVehicle(uid, {
        'vehicle_id': uid,
        'user_id': uid,
        'brand': '',
        'model': '',
        'plate': '',
        'vin': '',
      });

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterSuccessPage()),
      );
    } catch (e) {
      showMessage('Register failed: $e');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
