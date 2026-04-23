import 'package:flutter/material.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

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
                  "Language Settings",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26, // matches 26sp
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ================= CONTENT =================
              const Text(
                "Currently, EVSmart supports English language only.\n\n"
                "Additional languages such will be added in future updates.\n\n"
                "Thank you for your understanding.",
                style: TextStyle(
                  fontSize: 19, // matches 19sp
                  height: 1.6, // similar to lineSpacingExtra
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
