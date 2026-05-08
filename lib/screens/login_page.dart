import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_repository.dart';
import '../services/impact_detection_service.dart';
import 'forget_password.dart';
import 'health_home.dart';
import 'home_driver.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth mAuth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool rememberMe = false;
  bool isLoading = false;
  bool isBiometricAvailable = false;
  bool isBiometricLoading = false;
  String _savedRole = '';

  @override
  void initState() {
    super.initState();
    loadSavedLoginState();
  }

  Future<void> loadSavedLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username') ?? '';
    final savedRole = prefs.getString('saved_role') ?? '';

    if (savedUsername.isNotEmpty) {
      usernameController.text = savedUsername;
    }

    final deviceSupported = await _localAuth.isDeviceSupported();
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;

    if (!mounted) {
      return;
    }

    setState(() {
      rememberMe = savedUsername.isNotEmpty;
      _savedRole = savedRole;
      isBiometricAvailable =
          savedUsername.isNotEmpty &&
          savedRole.isNotEmpty &&
          mAuth.currentUser != null &&
          (deviceSupported || canCheckBiometrics);
    });
  }

  Future<void> loginUser() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      final snapshot = await AppRepository.usersRef
          .orderByChild('username')
          .equalTo(username)
          .get();
      if (!snapshot.exists) {
        final legacy = await AppRepository.legacyUsersRef
            .orderByChild('username')
            .equalTo(username)
            .get();
        if (!legacy.exists) {
          showMessage('Username not found');
          setState(() => isLoading = false);
          return;
        }

        final first = legacy.children.first;
        final email = first.child('email').value?.toString() ?? '';
        final uid = first.key!;
        await mAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await fetchUserRole(uid, username: username);
        return;
      }

      final first = snapshot.children.first;
      final email = first.child('email').value?.toString() ?? '';
      final uid = first.key!;
      await mAuth.signInWithEmailAndPassword(email: email, password: password);
      await fetchUserRole(uid, username: username);
    } catch (e) {
      showMessage('Wrong password or account');
      setState(() => isLoading = false);
    }
  }

  Future<void> _persistLoginState({
    required String username,
    required String uid,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('username', username);
      await prefs.setString('saved_uid', uid);
      await prefs.setString('saved_role', role);
    } else {
      await prefs.remove('username');
      await prefs.remove('saved_uid');
      await prefs.remove('saved_role');
    }
  }

  Future<void> fetchUserRole(String uid, {String? username}) async {
    final snapshot = await AppRepository.usersRef.child(uid).get();
    final legacySnapshot = await AppRepository.legacyUsersRef.child(uid).get();
    final data = snapshot.exists ? snapshot : legacySnapshot;

    if (!data.exists) {
      showMessage('User data missing');
      setState(() => isLoading = false);
      return;
    }

    final role = data.child('role').value?.toString() ?? '';
    if (role.isEmpty) {
      showMessage('Role not assigned');
      setState(() => isLoading = false);
      return;
    }

    await _persistLoginState(
      username: username ?? usernameController.text.trim(),
      uid: uid,
      role: role,
    );
    await redirectByRole(role);
  }

  Future<void> loginWithBiometrics() async {
    if (isBiometricLoading) {
      return;
    }

    final username = usernameController.text.trim();
    if (username.isEmpty || _savedRole.isEmpty || mAuth.currentUser == null) {
      showMessage('Sign in once with password and Remember Me first');
      return;
    }

    setState(() => isBiometricLoading = true);

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Use your fingerprint to sign in to EVSmart+',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!didAuthenticate) {
        setState(() => isBiometricLoading = false);
        return;
      }

      await _persistLoginState(
        username: username,
        uid: mAuth.currentUser!.uid,
        role: _savedRole,
      );
      await redirectByRole(_savedRole);
    } catch (_) {
      showMessage('Fingerprint sign-in is not available right now');
      setState(() => isBiometricLoading = false);
    }
  }

  Future<void> redirectByRole(String role) async {
    late final Widget page;
    final normalized = role.trim().toLowerCase();

    if (normalized.contains('driver')) {
      page = const DriverHomePage();
    } else if (normalized.contains('ambulance') ||
        normalized.contains('hospital')) {
      page = const HealthHomePage();
    } else {
      showMessage(
        'This app now supports EV Driver and Ambulance accounts only.',
      );
      setState(() => isLoading = false);
      return;
    }

    await ImpactDetectionService.maybeRequestBackgroundPermission(context);
    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              const Center(
                child: Text(
                  'EVSmart+ Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: _inputDecoration('Username'),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 50,
                child: TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: _inputDecoration('Password'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    activeColor: const Color(0xFF2E7D32),
                    value: rememberMe,
                    onChanged: (value) {
                      setState(() {
                        rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text(
                    'Remember Me',
                    style: TextStyle(color: Colors.black),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotMethodPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: isLoading ? null : loginUser,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              if (isBiometricAvailable) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                    onPressed: isBiometricLoading ? null : loginWithBiometrics,
                    icon: isBiometricLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: const Text(
                      'Use Fingerprint',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
    );
  }
}
