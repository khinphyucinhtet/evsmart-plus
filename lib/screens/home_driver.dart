import 'package:flutter/material.dart';

import 'menu.dart';
import 'charge.dart';
import 'alert.dart';
import 'noti.dart';
import 'rewards.dart';
import 'global_search.dart';
import 'app_header.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {

  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {

    final bottomPadding =
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [

          AppHeader(
            onSearch: (key) {
              key = key.toLowerCase().trim();
              if (_handleFunKeywords(key)) return;
              GlobalSearchHandler.handleSearch(context, key);
            },
          ),

          _buildBody(),
        ],
      ),
      bottomNavigationBar:
      _buildBottomNav(bottomPadding),
    );
  }

  Widget _buildBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Current Weather",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Container(
              height: 110,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF66BB6A)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "31°C",
                        style: TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight:
                            FontWeight.bold),
                      ),
                      Text(
                        "Clear Sky",
                        style: TextStyle(
                            color: Colors.white),
                      )
                    ],
                  ),

                  const Icon(
                    Icons.wb_sunny,
                    size: 48,
                    color: Colors.white,
                  )

                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: const [

                        Text(
                          "EV Battery",
                          style: TextStyle(
                              color: Colors.white70),
                        ),

                        SizedBox(height: 10),

                        Text(
                          "82%",
                          style: TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight:
                              FontWeight.bold),
                        ),

                        Text(
                          "Range 240 km",
                          style: TextStyle(
                              color: Colors.white),
                        )

                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(16),
                      color: Colors.grey.shade200,
                    ),
                    child: const Center(
                      child: Text(
                        "Nearby Charging\n12 km",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Nearby Charging",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [

                  _buildChargeCard(
                      "Shell Recharge",
                      "5 mins wait",
                      "2 chargers free"),

                  _buildChargeCard(
                      "ChargeEV i-City",
                      "No queue",
                      "4 chargers"),

                  _buildChargeCard(
                      "Tesla Supercharger",
                      "Queue: 2",
                      "6 chargers"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Charging Status",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [

                Expanded(
                  child: _buildStatusCard(
                      "Next Charger",
                      "1.8 km",
                      Icons.ev_station),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _buildStatusCard(
                      "Estimated Wait",
                      "10 mins",
                      Icons.timer),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Latest Update",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildAnnouncement(
                "No accident detected today",
                Icons.check_circle),

            _buildAnnouncement(
                "System check completed 10:15 AM",
                Icons.settings),

          ],
        ),
      ),
    );
  }

  // ================= ADDED WIDGETS =================

  Widget _buildChargeCard(
      String title,
      String wait,
      String chargers) {

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold),
          ),

          const Spacer(),

          Text(wait),

          Text(
            chargers,
            style: const TextStyle(
                color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      String title,
      String value,
      IconData icon) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
              blurRadius: 10,
              color: Colors.black12)
        ],
      ),
      child: Column(
        children: [

          Icon(icon,
              color: const Color(0xFF2E7D32)),

          const SizedBox(height: 10),

          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),

          Text(title,
              style: const TextStyle(
                  color: Colors.grey))

        ],
      ),
    );
  }

  Widget _buildAnnouncement(
      String text,
      IconData icon) {

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [

          Icon(icon,
              color: const Color(0xFF2E7D32)),

          const SizedBox(width: 10),

          Expanded(child: Text(text))

        ],
      ),
    );
  }

  // ================= FUN KEYWORD =================

  bool _handleFunKeywords(String key) {
    if (key.contains("zarul")) {
      _showPopup("STUPID", "Bangladeshiiii 😜");
      return true;
    }
    return false;
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK 😄"),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav(double bottomPadding) {
    return Container(
      height: 85 + bottomPadding,
      padding: EdgeInsets.only(
          top: 8,
          bottom: bottomPadding + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              blurRadius: 12,
              color: Colors.black12)
        ],
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceAround,
        children: [
          buildTab(Icons.home, "Home", 0),
          buildTab(Icons.ev_station, "Charge", 1),
          buildTab(Icons.warning, "Alert", 2),
          buildTab(Icons.notifications, "Noti", 3),
          buildTab(Icons.card_giftcard, "Rewards", 4),
        ],
      ),
    );
  }

  Widget buildTab(
      IconData icon,
      String label,
      int index) {

    final isActive =
        selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() =>
        selectedTab = index);

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const ChargePage()),
          );
        }

        if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const AlertPage()),
          );
        }

        if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const NotificationPage()),
          );
        }

        if (index == 4) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const RewardsPage()),
          );
        }
      },
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: isActive
                  ? const Color(0xFF2E7D32)
                  : Colors.grey),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? const Color(0xFF2E7D32)
                      : Colors.grey)),
        ],
      ),
    );
  }
}