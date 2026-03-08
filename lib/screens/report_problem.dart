import 'package:flutter/material.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {

  final List<Map<String, dynamic>> messages = [];
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool sessionStarted = false;

  @override
  void initState() {
    super.initState();
    addBotMessage("Hello 👋\nWelcome to EVSmart Support.");
  }

  void startSession() {
    setState(() {
      sessionStarted = true;
    });

    addBotMessage(
        "How can I help you today?\n\n"
            "Type one number:\n\n"
            "1️⃣ Can't Login\n"
            "2️⃣ App Crashes\n"
            "3️⃣ Profile Problem\n"
            "4️⃣ Payment Issue\n"
            "5️⃣ Charging Issue\n"
            "6️⃣ Find Nearby Charging Station\n"
            "7️⃣ Battery Draining Fast\n"
            "8️⃣ Rewards Issue\n"
            "9️⃣ Connect to Human Agent"
    );
  }

  void handleUserInput(String msg) {

    switch (msg) {
      case "1":
        addBotMessage("🔐 Login Problem:\n\n• Reset your password\n• Check internet\n• Restart app");
        break;
      case "2":
        addBotMessage("💥 App Crash:\n\n• Restart phone\n• Update app\n• Reinstall if needed");
        break;
      case "3":
        addBotMessage("👤 Profile Issue:\n\n• Fill all fields\n• Save properly\n• Re-login");
        break;
      case "4":
        addBotMessage("💳 Payment Issue:\n\n• Check balance\n• Verify method\n• Try later");
        break;
      case "5":
        addBotMessage("⚡ Charging Issue:\n\n• Check cable\n• Check station\n• Try another port");
        break;
      case "6":
        addBotMessage("📍 Finding Nearby Charging Stations...\n\nGo to the 'Charge' page.\nMake sure GPS is enabled.");
        break;
      case "7":
        addBotMessage("🔋 Battery Draining Fast:\n\n• Reduce background apps\n• Turn off unused features\n• Check battery health");
        break;
      case "8":
        addBotMessage("🎁 Rewards Issue:\n\n• Refresh rewards page\n• Check internet\n• Contact support");
        break;
      case "9":
        addBotMessage("🔎 Finding nearby human agent...");
        Future.delayed(const Duration(seconds: 2), () {
          addBotMessage("👨‍💼 Agent Connected.\nPlease wait...");
        });
        break;
      default:
        addBotMessage("❗ Command not available. Please type 1 - 9.");
    }
  }

  void addBotMessage(String msg) {
    setState(() {
      messages.add({"text": msg, "isUser": false});
    });
    scrollDown();
  }

  void addUserMessage(String msg) {
    setState(() {
      messages.add({"text": msg, "isUser": true});
    });
    scrollDown();
  }

  void scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),

      // ================= BOTTOM AREA FIXED =================
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 8),
        child: sessionStarted
            ? Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Type 1 - 9...",
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  String msg = controller.text.trim();
                  if (msg.isEmpty) return;

                  addUserMessage(msg);
                  handleUserInput(msg);
                  controller.clear();
                },
                child: const Text(
                  "Send",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        )
            : SizedBox(
          height: 46,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: startSession,
            child: const Text(
              "Get Started",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),

      // ================= MAIN BODY =================
      body: SafeArea(
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.white,
              child: const Center(
                child: Text(
                  "EVSmart Support",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  children: messages.map((msg) {
                    return buildMessageBubble(msg["text"], msg["isUser"]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(
          isUser ? 110 : 0,
          8,
          isUser ? 0 : 110,
          8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: isUser
              ? null
              : Border.all(color: const Color(0xFF2E7D32), width: 2),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}