import 'package:flutter/material.dart';

import 'menu.dart';
import 'home_driver.dart';
import 'charge.dart';
import 'alert.dart';
import 'noti.dart';
import 'global_search.dart';
import 'app_header.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() =>
      _RewardsPageState();
}

class _RewardsPageState
    extends State<RewardsPage> {

  bool isSearching = false;
  bool isListening = false;
  int selectedTab = 4; // Rewards active

  final TextEditingController searchController =
  TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final double statusBar =
        MediaQuery.of(context).padding.top;

    final double bottomSystem =
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [

          // ================= HEADER =================
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: statusBar,
              left: 12,
              right: 12,
            ),
            height: 75 + statusBar,
            color: const Color(0xFF2E7D32),
            child: Row(
              children: [

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const MenuPage()),
                    );
                  },
                  child: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: isSearching
                      ? _buildSearchBar()
                      : const Text(
                    "EVSmart+",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                if (!isSearching)
                  IconButton(
                    icon: const Icon(
                        Icons.search,
                        color: Colors.white),
                    onPressed: () {
                      setState(() {
                        isSearching = true;
                      });
                    },
                  ),
              ],
            ),
          ),

          // ================= MAIN CONTENT =================
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: const [

                  Text(
                    "Rewards Page",
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
                    "No rewards available yet",
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

  // ================= SEARCH BAR =================

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(
          horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: Row(
        children: [

          Expanded(
            child: TextField(
              controller: searchController,
              decoration:
              const InputDecoration(
                hintText: "Search...",
                border: InputBorder.none,
              ),
              onSubmitted: handleSearch,
            ),
          ),

          IconButton(
            icon: Icon(
              isListening
                  ? Icons.mic
                  : Icons.mic_none,
              color:
              const Color(0xFF2E7D32),
            ),
            onPressed: startListening,
          ),

          IconButton(
            icon:
            const Icon(Icons.close),
            onPressed: () {
              setState(() {
                isSearching = false;
                searchController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  // ================= VOICE =================

  void startListening() {
    GlobalSearchHandler.startVoice(
      context,
          (result) {
        handleSearch(result);
      },
          () {
        setState(() =>
        isListening = false);
      },
          () {
        setState(() =>
        isListening = true);
      },
    );
  }

  // ================= SEARCH =================

  void handleSearch(String key) {
    GlobalSearchHandler
        .handleSearch(context, key);
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

        if (index == 4) return;

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
                  ? const Color(
                  0xFF2E7D32)
                  : Colors.grey,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? const Color(
                    0xFF2E7D32)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}