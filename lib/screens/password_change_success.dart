import 'package:flutter/material.dart';

class PasswordChangeSuccessDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const PasswordChangeSuccessDialog({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            const Text(
              "Success!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),

            const SizedBox(height: 6),

            // Subtitle
            const Text(
              "Password changed successfully",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF666666)),
            ),

            const SizedBox(height: 22),

            // Icon
            const Icon(Icons.check_circle, size: 100, color: Color(0xFF2E7D32)),

            const SizedBox(height: 28),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: onContinue,
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 17, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
