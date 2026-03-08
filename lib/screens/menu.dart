import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'login_page.dart';
import 'change_password.dart';
import 'view_profile.dart';
import 'edit_profile.dart';
import 'support.dart';
import 'report_problem.dart';
import 'terms.dart';
import 'language.dart';
import 'privacy_policy.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  final DatabaseReference dbRef =
  FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL:
    "https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref("Users");

  bool showProfile = false;
  bool showHelp = false;
  bool showSettings = false;

  String userName = "User";
  String? profileImageBase64;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {

    if (mAuth.currentUser == null) return;

    final snapshot =
    await dbRef.child(mAuth.currentUser!.uid).get();

    if (!snapshot.exists) return;

    setState(() {
      userName =
          snapshot.child("fullName").value?.toString() ?? "User";

      profileImageBase64 =
          snapshot.child("profileImage").value?.toString();
    });
  }

  ImageProvider _buildProfileImage() {
    try {
      if (profileImageBase64 != null &&
          profileImageBase64!.isNotEmpty &&
          profileImageBase64 != "null") {

        final cleaned = profileImageBase64!
            .replaceAll("\n", "")
            .replaceAll("\r", "")
            .trim();

        return MemoryImage(base64Decode(cleaned));
      }
    } catch (_) {}

    return const AssetImage("assets/images/ic_user_profile.png");
  }

  Future<void> deleteAccount() async {

    if (mAuth.currentUser == null) return;

    String uid = mAuth.currentUser!.uid;

    await dbRef.child(uid).remove();
    await mAuth.currentUser!.delete();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  void showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to delete your account?\n\nThis action cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                deleteAccount();
              },
              child: const Text("Yes",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void logoutUser() {
    mAuth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [

          // ===== LIGHT OVERLAY (FIXED HERE) =====
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.white.withOpacity(0.6), // 👈 changed
            ),
          ),

          // ===== SIDE DRAWER PANEL =====
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 280,
              height: double.infinity,
              color: Colors.white,
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                          Colors.grey[300],
                          backgroundImage:
                          _buildProfileImage(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight:
                                FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),

                    buildSectionTitle("👤 Profile ▼", () {
                      setState(() {
                        showProfile = !showProfile;
                      });
                    }),

                    if (showProfile) ...[
                      buildItem("View Profile", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const ViewProfilePage()),
                        );
                      }),
                      buildItem("Edit Profile", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const EditProfilePage()),
                        );
                      }),
                      buildItem("Change Password", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const ChangePasswordPage()),
                        );
                      }),
                      buildItem("Delete Account",
                          showDeleteDialog,
                          color: Colors.red),
                      buildItem("Logout", logoutUser),
                    ],

                    buildSectionTitle(
                        "❓ Help And Support ▼", () {
                      setState(() {
                        showHelp = !showHelp;
                      });
                    }),

                    if (showHelp) ...[
                      buildItem("Support", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const SupportPage()),
                        );
                      }),
                      buildItem("Report Problem", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const ReportProblemPage()),
                        );
                      }),
                      buildItem(
                          "Terms And Conditions", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const TermsPage()),
                        );
                      }),
                    ],

                    buildSectionTitle(
                        "⚙️ Settings And Privacy ▼", () {
                      setState(() {
                        showSettings = !showSettings;
                      });
                    }),

                    if (showSettings) ...[
                      buildItem("Language", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const LanguagePage()),
                        );
                      }),
                      buildItem("Privacy Policy", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                              const PrivacyPolicyPage()),
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

  Widget buildSectionTitle(
      String title, VoidCallback onTap) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildItem(String title,
      VoidCallback onTap,
      {Color color = Colors.black}) {
    return Padding(
      padding:
      const EdgeInsets.only(left: 12, bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          title,
          style: TextStyle(
              fontSize: 15,
              color: color),
        ),
      ),
    );
  }
}