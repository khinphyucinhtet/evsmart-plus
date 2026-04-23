import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
                  "Terms and Conditions",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================= INTRO =================
              const Text(
                "Welcome to EVSmart. By using this application, you agree to follow and be bound by the terms and conditions stated below. Please read them carefully before using the system.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              sectionTitle("1. User Account and Registration"),
              const SizedBox(height: 10),
              const Text(
                "Users must provide accurate and complete information during registration. Each user is responsible for maintaining the confidentiality of their login credentials. Sharing accounts with other users is strictly prohibited.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("2. Use of EVSmart Services"),
              const SizedBox(height: 10),
              const Text(
                "EVSmart provides users with access to electric vehicle information, profile management, charging station support, and related services. The application is intended for personal and educational use only. Commercial use without permission is not allowed.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("3. User Responsibilities"),
              const SizedBox(height: 10),
              const Text(
                "Users are expected to use the application responsibly. Any attempt to misuse the system, upload harmful content, provide false information, or interfere with system functionality is strictly prohibited.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("4. Data Privacy and Protection"),
              const SizedBox(height: 10),
              const Text(
                "EVSmart respects user privacy and follows the Personal Data Protection Act (PDPA). User information such as name, contact details, and profile images are securely stored and used only for system functionality and service improvement.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("5. Security and Account Safety"),
              const SizedBox(height: 10),
              const Text(
                "Users are responsible for keeping their passwords secure. EVSmart is not responsible for losses caused by unauthorized access due to weak passwords or careless sharing of login details.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("6. System Availability"),
              const SizedBox(height: 10),
              const Text(
                "EVSmart aims to provide continuous and reliable service. However, temporary interruptions may occur due to maintenance, technical issues, or system upgrades. The developers are not liable for any inconvenience caused.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("7. Prohibited Activities"),
              const SizedBox(height: 10),
              const Text(
                "Users must not engage in hacking, reverse engineering, spamming, spreading malware, or any illegal activity through the application. Violations may result in permanent account suspension.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("8. Account Termination"),
              const SizedBox(height: 10),
              const Text(
                "EVSmart reserves the right to suspend or delete user accounts that violate these terms. Users may also request account deletion through the application settings.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("9. Changes to Terms"),
              const SizedBox(height: 10),
              const Text(
                "EVSmart may update these Terms and Conditions from time to time. Continued use of the application after updates indicates acceptance of the revised terms.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 20),

              sectionTitle("10. Agreement"),
              const SizedBox(height: 10),
              const Text(
                "By using EVSmart, you acknowledge that you have read, understood, and agreed to these Terms and Conditions.",
                style: TextStyle(fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  "Last Updated: February 2026",
                  style: TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2E7D32),
      ),
    );
  }
}
