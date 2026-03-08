import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_driver.dart';
import 'charge.dart';
import 'alert.dart';
import 'noti.dart';
import 'rewards.dart';
import 'view_profile.dart';
import 'edit_profile.dart';
import 'report_problem.dart';
import 'terms.dart';
import 'support.dart';
import 'change_password.dart';
import 'login_page.dart';
import 'language.dart';
import 'privacy_policy.dart';

class GlobalSearchHandler {

  static const MethodChannel platform =
  MethodChannel("voice_channel");

  // ================= VOICE =================

  static Future<void> startVoice(
      BuildContext context,
      Function(String) onResult,
      Function() onStop,
      Function() onStart,
      ) async {

    try {
      onStart();

      final result =
      await platform.invokeMethod("startVoice");

      onStop();

      if (result != null &&
          result.toString().isNotEmpty) {
        onResult(result.toString());
      }

    } catch (_) {

      onStop();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text("Voice not available"),
        ),
      );
    }
  }

  // ================= SEARCH =================

  static void handleSearch(
      BuildContext context,
      String key) {

    key = key.toLowerCase().trim();

    // ===== FUN KEYWORDS FIRST =====
    if (_handleFunKeywords(context, key)) {
      return;
    }

    // ===== HELP =====
    if (key.contains("help") ||
        key.contains("assist") ||
        key.contains("emergency") ||
        key.contains("accident") ||
        key.contains("need assistance") ||
        key.contains("i need help")) {

      _showHelpDialog(context);
      return;
    }

    // ===== PROFILE =====
    if (key.contains("edit profile")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const EditProfilePage()),
      );
      return;
    }

    if (key.contains("view profile") ||
        key.contains("profile")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const ViewProfilePage()),
      );
      return;
    }

    // ===== PASSWORD =====
    if (key.contains("change password") ||
        key.contains("reset password") ||
        key.contains("password")) {

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const ChangePasswordPage()),
      );
      return;
    }

    // ===== REPORT =====
    if (key.contains("report") ||
        key.contains("help bot") ||
        key.contains("chat bot")) {

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const ReportProblemPage()),
      );
      return;
    }

    // ===== SUPPORT =====
    if (key.contains("support")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const SupportPage()),
      );
      return;
    }

    // ===== TERMS =====
    if (key.contains("terms")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const TermsPage()),
      );
      return;
    }

    // ===== LANGUAGE =====
    if (key.contains("language")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const LanguagePage()),
      );
      return;
    }

    // ===== PRIVACY =====
    if (key.contains("privacy")) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const PrivacyPolicyPage()),
      );
      return;
    }

    // ===== LOGOUT =====
    if (key.contains("logout") ||
        key.contains("log out")) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const LoginPage()),
      );
      return;
    }

    // ===== MAIN NAV =====
    if (key.contains("home")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const DriverHomePage()),
      );
      return;
    }

    if (key.contains("charge")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const ChargePage()),
      );
      return;
    }

    if (key.contains("alert")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const AlertPage()),
      );
      return;
    }

    if (key.contains("noti")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const NotificationPage()),
      );
      return;
    }

    if (key.contains("reward")) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
            const RewardsPage()),
      );
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
        Text("Command not recognized"),
      ),
    );
  }

  // ================= FUN KEYWORDS =================

  static bool _handleFunKeywords(
      BuildContext context,
      String key) {

    if (key.contains("zarul") ||
        key.contains("zarulll") ||
        key.contains("bangla") ||
        key.contains("bangladeshii") ||
        key.contains("sorrow")) {

      _showSimplePopup(
          context,
          "STUPID",
          "Zarul The Bangladeshii");
      return true;
    }

    if (key.contains("ryan") ||
        key.contains("ryan danish")) {

      _showSimplePopup(
          context,
          "STUPID",
          "Ryan Bodoh");
      return true;
    }

    if (key.contains("laku") ||
        key.contains("indian") ||
        key.contains("lakulesh")) {

      _showSimplePopup(
          context,
          "STUPID",
          "Laku the Indian");
      return true;
    }

    if (key.contains("arab") ||
        key.contains("shihab") ||
        key.contains("arab bombastic")) {

      _showSimplePopup(
          context,
          "ARAB",
          "ARAB BOMBASTICCC SIDE EYE");
      return true;
    }

    return false;
  }

  static void _showSimplePopup(
      BuildContext context,
      String title,
      String message) {

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ================= HELP DIALOG =================

  static void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        int progress = 0;
        bool isCompleted = false;

        return StatefulBuilder(
          builder: (context, setState) {
            // Start progress ONLY once
            if (progress == 0) {
              Future.delayed(const Duration(milliseconds: 25), () async {
                while (progress < 100) {
                  await Future.delayed(
                      const Duration(milliseconds: 25));
                  progress++;
                  setState(() {});
                }

                isCompleted = true;
                setState(() {});
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ===== TITLE =====
                    const Text(
                      "We Got You 💚",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ===== SUBTITLE =====
                    const Text(
                      "Requesting help... Please wait",
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF444444),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== PROGRESS BAR =====
                    SizedBox(
                      width: 250,
                      height: 12,
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                        const AlwaysStoppedAnimation(
                            Color(0xFF2E7D32)),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ===== OK BUTTON =====
                    SizedBox(
                      width: 160,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: isCompleted
                            ? () => Navigator.pop(context)
                            : null,
                        child: const Text(
                          "OK",
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }}