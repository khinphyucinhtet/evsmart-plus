import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'register_success.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL:
    "https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref("Users");

  String selectedRole = "Select User Type";
  bool isLoading = false;

  final List<String> roles = [
    "Select User Type",
    "EV Driver",
    "Admin",
    "Mechanic"
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [

              const SizedBox(height: 10),

              buildLabel("Full Name"),
              buildField(fullNameController, "Eg: Pinky"),

              buildLabel("ID Number"),
              buildField(idController, "Eg: 1234567890"),

              buildLabel("Phone Number"),
              buildField(phoneController, "Eg: 0123456789",
                  inputType: TextInputType.phone),

              buildLabel("Email Address"),
              buildField(emailController, "Eg: pinky@gmail.com",
                  inputType: TextInputType.emailAddress),

              buildLabel("Username"),
              buildField(usernameController, "Eg: pinky00"),

              buildLabel("Password"),
              buildField(passwordController, "Enter password",
                  obscure: true),

              buildLabel("Confirm Password"),
              buildField(confirmPasswordController, "Re-enter password",
                  obscure: true),

              const SizedBox(height: 10),

              buildLabel("Select Your User Type"),

              DropdownButtonFormField<String>(
                value: selectedRole,
                items: roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                    const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E7D32),
                      width: 2,
                    ),
                  ),
                ),
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
                  onPressed:
                  isLoading ? null : registerUser,
                  child: isLoading
                      ? const CircularProgressIndicator(
                      color: Colors.white)
                      : const Text(
                    "Create Account",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ================= LABEL =================
  Widget buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding:
        const EdgeInsets.only(bottom: 6, top: 15),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // ================= TEXT FIELD =================
  Widget buildField(TextEditingController controller,
      String hint,
      {bool obscure = false,
        TextInputType inputType = TextInputType.text}) {

    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: inputType,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: Colors.grey),

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
    );
  }

  // ================= REGISTER =================
  void registerUser() async {

    String fullName = fullNameController.text.trim();
    String idNumber = idController.text.trim();
    String phone = phoneController.text.trim();
    String email = emailController.text.trim();
    String username = usernameController.text.trim();
    String password = passwordController.text;
    String confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty ||
        idNumber.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {

      showMessage("Please fill all fields");
      return;
    }

    if (password.length < 6) {
      showMessage(
          "Password must be at least 6 characters");
      return;
    }

    if (password != confirmPassword) {
      showMessage("Passwords do not match");
      return;
    }

    if (selectedRole == "Select User Type") {
      showMessage("Please select user type");
      return;
    }

    setState(() => isLoading = true);

    try {

      UserCredential userCredential =
      await mAuth.createUserWithEmailAndPassword(
          email: email,
          password: password);

      String uid = userCredential.user!.uid;

      await dbRef.child(uid).set({
        "uid": uid,
        "fullName": fullName,
        "idNumber": idNumber,
        "phone": phone,
        "email": email,
        "username": username,
        "role": selectedRole,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const RegisterSuccessPage(),
        ),
      );

    } catch (e) {
      showMessage("Register failed: $e");
    }

    setState(() => isLoading = false);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}