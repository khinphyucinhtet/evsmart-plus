import 'package:flutter/material.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

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
                  "EVSmart Support Center",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ================= INTRO =================
              const Text(
                "Welcome to the EVSmart Support Center. We are here to assist you with any issues related to account management, charging services, and application usage.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ================= CONTACT INFO =================
              sectionTitle("Contact Information"),

              const SizedBox(height: 10),

              const Text(
                "Email: support@evsmart.com\n"
                "Phone: +60 12-3456789\n"
                "Working Hours: Monday to Friday, 9:00 AM – 6:00 PM",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ================= COMMON ISSUES =================
              sectionTitle("Common Support Topics"),

              const SizedBox(height: 8),

              const Text(
                "• Login and authentication problems\n"
                "• Profile and account updates\n"
                "• Charging station connection issues\n"
                "• Payment and transaction errors\n"
                "• Application crashes or slow performance\n"
                "• Map and station location inaccuracies",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ================= SELF HELP =================
              sectionTitle("Self-Help Guidelines"),

              const SizedBox(height: 10),

              const Text(
                "Before contacting support, we recommend users to ensure they are using the latest version of the application, check their internet connection, and restart the application if necessary.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ================= RESPONSE TIME =================
              sectionTitle("Response Time"),

              const SizedBox(height: 10),

              const Text(
                "Our support team aims to respond to all inquiries within 24 working hours. Complex technical issues may require additional investigation time.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ================= EMERGENCY =================
              sectionTitle("Emergency Support"),

              const SizedBox(height: 10),

              const Text(
                "For urgent charging failures or safety-related issues, please contact our emergency hotline immediately during operating hours.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // ================= FOOTER =================
              const Center(
                child: Text(
                  "EVSmart Support Team\nCommitted to providing reliable and efficient service.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SECTION TITLE WIDGET =================
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
