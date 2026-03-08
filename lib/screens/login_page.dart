import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register.dart';
import 'home_driver.dart';
import 'forget_password.dart';
import 'health_home.dart';
import 'tech_home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  final DatabaseReference userRef =
  FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL:
    "https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref("Users");

  bool rememberMe = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadSavedUsername();
  }

  Future<void> loadSavedUsername() async {
    SharedPreferences prefs =
    await SharedPreferences.getInstance();

    String savedUsername =
        prefs.getString("username") ?? "";

    if (savedUsername.isNotEmpty) {
      usernameController.text = savedUsername;
      setState(() {
        rememberMe = true;
      });
    }
  }

  // ================= LOGIN =================
  Future<void> loginUser() async {

    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showMessage("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {

      final snapshot =
      await userRef
          .orderByChild("username")
          .equalTo(username)
          .get();

      if (!snapshot.exists) {
        showMessage("Username not found");
        setState(() => isLoading = false);
        return;
      }

      String? email;
      String? uid;

      for (final child in snapshot.children) {
        email = child.child("email").value?.toString();
        uid = child.key;
        break;
      }

      if (email == null || email.isEmpty) {
        showMessage("Account error: No email");
        setState(() => isLoading = false);
        return;
      }

      await mAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      SharedPreferences prefs =
      await SharedPreferences.getInstance();

      if (rememberMe) {
        await prefs.setString("username", username);
      } else {
        await prefs.remove("username");
      }

      await fetchUserRole(uid!);

    } catch (e) {
      showMessage("Wrong password or account");
      setState(() => isLoading = false);
    }
  }

  // ================= FETCH ROLE =================
  Future<void> fetchUserRole(String uid) async {

    final snapshot =
    await userRef.child(uid).get();

    if (!snapshot.exists) {
      showMessage("User data missing");
      setState(() => isLoading = false);
      return;
    }

    String? role =
    snapshot.child("role").value?.toString();

    if (role == null || role.isEmpty) {
      showMessage("Role not assigned");
      setState(() => isLoading = false);
      return;
    }

    redirectByRole(role);
  }

  // ================= REDIRECT =================
  void redirectByRole(String role) {

    Widget page;

    switch (role) {

      case "EV Driver (User)":
        page = const DriverHomePage();
        break;

      case "Hospital Staff / Ambulance":
        page = const HealthHomePage();
        break;

      case "Towing Technician":
        page = const TechHomePage();
        break;

      default:
        showMessage("Invalid role: $role");
        setState(() => isLoading = false);
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
          (route) => false,
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
        SnackBar(content: Text(message)));
  }

  // ================= UI =================
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
                  "EVSmart+ Login",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ================= USERNAME =================
              SizedBox(
                height: 50,
                child: TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Username",
                    hintStyle:
                    const TextStyle(color: Colors.grey),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),

                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(6),
                      borderSide:
                      const BorderSide(color: Colors.grey),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E7D32),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ================= PASSWORD =================
              SizedBox(
                height: 50,
                child: TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Password",
                    hintStyle:
                    const TextStyle(color: Colors.grey),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),

                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(6),
                      borderSide:
                      const BorderSide(color: Colors.grey),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E7D32),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ================= REMEMBER + FORGOT =================
              Row(
                children: [

                  Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme:
                      CheckboxThemeData(
                        fillColor:
                        MaterialStateProperty.resolveWith(
                                (states) {
                              if (states.contains(
                                  MaterialState.selected)) {
                                return const Color(
                                    0xFF2E7D32);
                              }
                              return Colors.white;
                            }),
                      ),
                    ),
                    child: Checkbox(
                      value: rememberMe,
                      onChanged: (value) {
                        setState(() {
                          rememberMe =
                              value ?? false;
                        });
                      },
                    ),
                  ),

                  const Text(
                    "Remember Me",
                    style:
                    TextStyle(color: Colors.black),
                  ),

                  const Spacer(),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const ForgotMethodPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ================= SIGN IN =================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF2E7D32),
                  ),
                  onPressed:
                  isLoading ? null : loginUser,
                  child: isLoading
                      ? const CircularProgressIndicator(
                      color: Colors.white)
                      : const Text(
                    "Sign In",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const RegisterPage(),
                    ),
                  );
                },
                child: const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
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
}