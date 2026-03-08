import 'package:flutter/material.dart';
import 'code_verify.dart';

class ForgotPhonePage extends StatefulWidget {
  const ForgotPhonePage({super.key});

  @override
  State<ForgotPhonePage> createState() =>
      _ForgotPhonePageState();
}

class _ForgotPhonePageState
    extends State<ForgotPhonePage> {

  final TextEditingController phoneController =
  TextEditingController();

  final List<String> countryCodes = [
    "🇲🇾 +60",
    "🇸🇬 +65",
    "🇺🇸 +1",
    "🇬🇧 +44",
    "🇯🇵 +81",
    "🇰🇷 +82",
    "🇨🇳 +86",
    "🇮🇳 +91",
    "🇦🇺 +61",
    "🇩🇪 +49",
  ];

  String selectedCode = "🇲🇾 +60";

  void sendSMS() {

    if (phoneController.text.trim().isEmpty) {
      showMessage("Enter phone number");
      return;
    }

    showMessage("SMS will be sent shortly");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CodeVerifyPage(),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const Text(
                  "Reset via Phone",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [

                    Container(
                      width: 110,
                      height: 50,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF2E7D32)),
                        borderRadius:
                        BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: selectedCode,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: countryCodes
                            .map((code) =>
                            DropdownMenuItem(
                              value: code,
                              child: Text(
                                code,
                                style: const TextStyle(
                                    color: Colors.black),
                              ),
                            ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCode = value!;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                            color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          hintStyle: const TextStyle(
                              color: Colors.grey),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.grey),
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Color(0xFF2E7D32),
                                width: 2),
                            borderRadius:
                            BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF2E7D32),
                    ),
                    onPressed: sendSMS,
                    child: const Text(
                      "Send SMS",
                      style: TextStyle(
                          color: Colors.white),
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