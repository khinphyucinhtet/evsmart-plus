import 'package:flutter/material.dart';

import 'menu.dart';
import 'home_driver.dart';
import 'charge.dart';
import 'noti.dart';
import 'rewards.dart';
import 'global_search.dart';
import 'app_header.dart';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  State<AlertPage> createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {

  int selectedTab = 2; // Alert active

  @override
  Widget build(BuildContext context) {

    final double bottomSystem =
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [

          // ✅ NEW REUSABLE HEADER
          AppHeader(
            onSearch: (key) {
              GlobalSearchHandler
                  .handleSearch(context, key);
            },
          ),

          // ================= MAIN CONTENT =================
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [

                  Text(
                    "Alert Page",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      Color(0xFF43A047),
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    "No alerts detected",
                    style: TextStyle(
                      fontSize: 16,
                      color:
                      Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ================= BOTTOM NAV =================
      bottomNavigationBar: Container(
        height: 85 + bottomSystem,
        padding: EdgeInsets.only(
          top: 8,
          bottom: bottomSystem + 8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black12,
            )
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
      ),
    );
  }

  // ================= TAB BUILDER =================

  Widget buildTab(
      IconData icon,
      String label,
      int index) {

    bool isActive =
        selectedTab == index;

    return GestureDetector(
      onTap: () {

        if (index == 2) return;

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const DriverHomePage()),
          );
        }

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const ChargePage()),
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
      child: Container(
        width: 70,
        decoration: isActive
            ? BoxDecoration(
          color: const Color(0xFF2E7D32)
              .withOpacity(0.1),
          borderRadius:
          BorderRadius.circular(12),
        )
            : null,
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 24,
              color: isActive
                  ? const Color(0xFF2E7D32)
                  : Colors.grey,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? const Color(0xFF2E7D32)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}