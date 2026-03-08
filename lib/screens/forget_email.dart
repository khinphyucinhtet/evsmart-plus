import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class ForgotEmailPage extends StatefulWidget {
  const ForgotEmailPage({super.key});

  @override
  State<ForgotEmailPage> createState() =>
      _ForgotEmailPageState();
}

class _ForgotEmailPageState
    extends State<ForgotEmailPage> {

  final TextEditingController emailController =
  TextEditingController();

  final FirebaseAuth mAuth =
      FirebaseAuth.instance;

  bool isLoading = false;

  Future<void> sendResetEmail() async {

    String email =
    emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
          "Enter your registered email");
      return;
    }

    setState(() => isLoading = true);

    try {

      await mAuth.sendPasswordResetEmail(
          email: email);

      showMessage(
          "Reset link sent. Check your email.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const LoginPage()),
            (route) => false,
      );

    } catch (e) {
      showMessage(
          "Email not found in system");
      setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [

                const Text(
                  "Reset via Email",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 25),

                TextField(
                  controller:
                  emailController,
                  keyboardType:
                  TextInputType.emailAddress,
                  decoration:
                  InputDecoration(
                    hintText:
                    "Enter your email",
                    hintStyle:
                    const TextStyle(
                        color:
                        Colors.grey),
                    enabledBorder:
                    OutlineInputBorder(
                      borderSide:
                      const BorderSide(
                          color:
                          Colors.grey),
                      borderRadius:
                      BorderRadius.circular(
                          4),
                    ),
                    focusedBorder:
                    OutlineInputBorder(
                      borderSide:
                      const BorderSide(
                          color:
                          Color(
                              0xFF2E7D32),
                          width: 2),
                      borderRadius:
                      BorderRadius.circular(
                          4),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width:
                  double.infinity,
                  height: 50,
                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(
                          0xFF2E7D32),
                    ),
                    onPressed:
                    isLoading
                        ? null
                        : sendResetEmail,
                    child:
                    isLoading
                        ? const CircularProgressIndicator(
                        color:
                        Colors.white)
                        : const Text(
                      "Send Code",
                      style:
                      TextStyle(
                          color:
                          Colors.white),
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
}