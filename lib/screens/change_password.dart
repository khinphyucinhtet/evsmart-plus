import 'package:flutter/material.dart';
import 'password_change_success.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool isLoading = false;

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  Future<void> changePassword() async {
    final currentPass = currentPasswordController.text.trim();
    String pass = passwordController.text.trim();
    String confirm = confirmController.text.trim();

    if (currentPass.isEmpty || pass.isEmpty || confirm.isEmpty) {
      showMessage("Please fill all fields");
      return;
    }

    if (pass.length < 6) {
      showMessage("Password must be at least 6 characters");
      return;
    }

    if (pass != confirm) {
      showMessage("Passwords do not match");
      return;
    }

    if (mAuth.currentUser == null) {
      showMessage("Please log in first or use Reset via Email.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = mAuth.currentUser!;
      final email = user.email?.trim() ?? '';
      if (email.isEmpty) {
        setState(() => isLoading = false);
        _showResultDialog(
          title: 'Password Update Failed',
          message:
              'Your account email could not be verified. Please sign in again and retry.',
        );
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPass,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(pass);

      setState(() => isLoading = false);

      showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        _showResultDialog(
          title: 'Current Password Incorrect',
          message:
              'The current password you entered is incorrect. Please try again.',
        );
      } else if (e.code == 'requires-recent-login') {
        _showResultDialog(
          title: 'Please Sign In Again',
          message:
              'Your session expired for password changes. Please log in again, then retry.',
        );
      } else if (e.code == 'weak-password') {
        _showResultDialog(
          title: 'Password Too Weak',
          message:
              'Please use a stronger new password with at least 6 characters.',
        );
      } else {
        _showResultDialog(
          title: 'Password Update Failed',
          message: e.message ?? "Error changing password",
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showResultDialog(
        title: 'Password Update Failed',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordChangeSuccessDialog(
        onContinue: () {
          Navigator.pop(context);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
      ),
    );
  }

  void _showResultDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: 132,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Ok',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          child: Column(
            children: [
              const Text(
                "Reset Password",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Current Password",
                  hintStyle: const TextStyle(color: Colors.grey),

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

              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Enter New Password",
                  hintStyle: const TextStyle(color: Colors.grey),

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

              const SizedBox(height: 16),

              // ================= CONFIRM PASSWORD =================
              TextField(
                controller: confirmController,
                obscureText: true,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Confirm New Password",
                  hintStyle: const TextStyle(color: Colors.grey),

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

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: isLoading ? null : changePassword,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Change Password",
                          style: TextStyle(color: Colors.white, fontSize: 17),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
