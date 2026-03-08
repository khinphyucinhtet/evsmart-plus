import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================= TITLE =================
              const Center(
                child: Text(
                  "Privacy Policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24, // matches 24sp
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ================= CONTENT =================
              const Text(
                "EVSmart respects your privacy and is committed to protecting your personal information.\n\n"
                    "We collect basic user data such as name, email, phone number, and profile image for account management purposes.\n\n"
                    "All data is securely stored using Firebase services and is not shared with third parties.\n\n"
                    "We comply with Malaysia’s Personal Data Protection Act (PDPA).\n\n"
                    "Users may request data deletion at any time through account settings.",
                style: TextStyle(
                  fontSize: 19, // matches 19sp
                  height: 1.6,  // similar to lineSpacingExtra
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}