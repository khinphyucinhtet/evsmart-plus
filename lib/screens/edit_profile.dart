import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {

  final FirebaseAuth mAuth = FirebaseAuth.instance;

  final DatabaseReference dbRef =
  FirebaseDatabase.instanceFor(
    app: FirebaseAuth.instance.app,
    databaseURL:
    "https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref("Users");

  final ImagePicker picker = ImagePicker();

  // Controllers
  final fullNameController = TextEditingController();
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final plateController = TextEditingController();
  final vinController = TextEditingController();

  String selectedBrand = "Select Brand";
  String selectedModel = "Select Model";

  String encodedImage = "";
  String? profileImageBase64;

  // ================= BRAND LIST =================
  final List<String> brands = [
    "Select Brand",
    "AION","Audi","BMW","BYD","Bentley","Chery","Citroen","Deepal",
    "Dongfeng","Fiat","Ford","Foton","GWM","Higer","Honda","Hyundai",
    "IM","JAC","Kia","Leapmotor","Lexus","MG","Mercedes-Benz",
    "Mitsubishi","Neta","Nissan","Proton","Tesla","Toyota",
    "Xpeng","Zeekr"
  ];

  // ================= MODEL MAP =================
  final Map<String, List<String>> modelMap = {
    "AION": ["Select Model","Aion Y Plus","Aion ES EV","Aion V"],
    "Audi": ["Select Model","Q4 e-tron","Q8 e-tron","SQ8 e-tron"],
    "BMW": ["Select Model","i4","iX","i7"],
    "BYD": ["Select Model","Atto 3","Dolphin","Seal"],
    "Bentley": ["Select Model","Bentayga Hybrid","Flying Spur Hybrid","Continental GT Hybrid"],
    "Chery": ["Select Model","EQ1","EQ5","Little Ant"],
    "Citroen": ["Select Model","e-C4","e-Berlingo","Ami EV"],
    "Deepal": ["Select Model","SL03","S7","G318 EV"],
    "Dongfeng": ["Select Model","Nammi 01","E70","EX1"],
    "Fiat": ["Select Model","500e","E-Ulysse","E-Doblò"],
    "Ford": ["Select Model","Mustang Mach-E","F-150 Lightning","E-Transit"],
    "Foton": ["Select Model","iBlue EV","Toano EV","Aumark EV"],
    "GWM": ["Select Model","Ora Good Cat","Ora Funky Cat","Tank 500 EV"],
    "Higer": ["Select Model","KLQ EV Bus","Azure EV","Urban EV"],
    "Honda": ["Select Model","e:NS1","e:NP1","Honda e"],
    "Hyundai": ["Select Model","Ioniq 5","Ioniq 6","Kona Electric"],
    "IM": ["Select Model","LS7","L7","LS6"],
    "JAC": ["Select Model","E-J7","iEV7S","iEV6E"],
    "Kia": ["Select Model","EV6","EV9","Niro EV"],
    "Leapmotor": ["Select Model","C11","T03","C01"],
    "Lexus": ["Select Model","RZ 450e","UX 300e","LF-ZC"],
    "MG": ["Select Model","MG4 EV","ZS EV","Marvel R"],
    "Mercedes-Benz": ["Select Model","EQS","EQE","EQA"],
    "Mitsubishi": ["Select Model","i-MiEV","Outlander PHEV","Minicab EV"],
    "Neta": ["Select Model","V","X","S"],
    "Nissan": ["Select Model","Leaf","Ariya","Sakura"],
    "Proton": ["Select Model","e.MAS 7","Iriz EV","Persona EV"],
    "Tesla": ["Select Model","Model 3","Model Y","Model S"],
    "Toyota": ["Select Model","bZ4X","C+pod","Proace EV"],
    "Xpeng": ["Select Model","P7","G9","G6"],
    "Zeekr": ["Select Model","001","X","009"],
  };

  List<String> currentModels = ["Select Model"];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  // ================= SAFE IMAGE BUILDER =================
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
    } catch (e) {
      debugPrint("Base64 decode error: $e");
    }

    return const AssetImage("assets/images/ic_user_profile.png");
  }

  // ================= LOAD USER =================
  Future<void> loadUserData() async {

    if (mAuth.currentUser == null) return;

    String uid = mAuth.currentUser!.uid;

    final snapshot = await dbRef.child(uid).get();
    if (!snapshot.exists) return;

    setState(() {

      fullNameController.text = snapshot.child("fullName").value?.toString() ?? "";
      idController.text = snapshot.child("idNumber").value?.toString() ?? "";
      phoneController.text = snapshot.child("phone").value?.toString() ?? "";
      emailController.text = snapshot.child("email").value?.toString() ?? "";
      usernameController.text = snapshot.child("username").value?.toString() ?? "";
      plateController.text = snapshot.child("plate").value?.toString() ?? "";
      vinController.text = snapshot.child("vin").value?.toString() ?? "";

      selectedBrand = snapshot.child("brand").value?.toString() ?? "Select Brand";

      if (modelMap.containsKey(selectedBrand)) {
        currentModels = modelMap[selectedBrand]!;
      }

      selectedModel = snapshot.child("model").value?.toString() ?? "Select Model";

      profileImageBase64 = snapshot.child("profileImage").value?.toString();
    });
  }

  // ================= IMAGE PICK =================
  Future<void> pickImage() async {

    final XFile? picked =
    await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();

    setState(() {
      encodedImage = base64Encode(bytes);
      profileImageBase64 = encodedImage;
    });
  }

  // ================= UPDATE =================
  Future<void> updateProfile() async {

    if (selectedBrand == "Select Brand") {
      showMessage("Select brand");
      return;
    }

    if (selectedModel == "Select Model") {
      showMessage("Select model");
      return;
    }

    String uid = mAuth.currentUser!.uid;

    await dbRef.child(uid).update({
      "fullName": fullNameController.text.trim(),
      "idNumber": idController.text.trim(),
      "phone": phoneController.text.trim(),
      "email": emailController.text.trim(),
      "username": usernameController.text.trim(),
      "brand": selectedBrand,
      "model": selectedModel,
      "plate": plateController.text.trim(),
      "vin": vinController.text.trim(),
    });

    if (encodedImage.isNotEmpty) {
      await dbRef.child(uid).child("profileImage").set(encodedImage);
    }

    showMessage("Profile Updated");
    Navigator.pop(context);
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [

              const SizedBox(height: 10),

              const Text(
                "Edit Profile",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),

              const SizedBox(height: 20),

              CircleAvatar(
                radius: 65,
                backgroundColor: Colors.grey[200],
                backgroundImage: _buildProfileImage(),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: pickImage,
                child: const Text("Upload Picture",
                    style: TextStyle(color: Colors.white)),
              ),

              buildField("Full Name", fullNameController),
              buildField("ID Number", idController),
              buildField("Phone Number", phoneController),
              buildField("Email Address", emailController),
              buildField("Username", usernameController),

              const SizedBox(height: 10),

              const Text("My Vehicles",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),

              const SizedBox(height: 8),

              buildBrandDropdown(),
              const SizedBox(height: 12),
              buildModelDropdown(),

              buildField("Plate Number (Optional)", plateController),
              buildField("VIN (Optional)", vinController),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: updateProfile,
                  child: const Text("Save Changes",
                      style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBrandDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedBrand,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      items: brands.map((brand) {
        return DropdownMenuItem(
          value: brand,
          child: Text(brand),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedBrand = value!;
          currentModels = modelMap[value] ?? ["Select Model"];
          selectedModel = currentModels.first;
        });
      },
    );
  }

  Widget buildModelDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedModel,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
      items: currentModels.map((model) {
        return DropdownMenuItem(
          value: model,
          child: Text(model),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedModel = value!;
        });
      },
    );
  }
}