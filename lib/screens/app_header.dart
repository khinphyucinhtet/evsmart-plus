import 'package:flutter/material.dart';
import 'global_search.dart';
import 'menu.dart';

class AppHeader extends StatefulWidget {

  final Function(String) onSearch;

  const AppHeader({
    super.key,
    required this.onSearch,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {

  bool isSearching = false;
  bool isListening = false;

  final TextEditingController searchController =
  TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final statusBar =
        MediaQuery.of(context).padding.top;

    return Container(
      height: 75 + statusBar,
      padding: EdgeInsets.only(
          top: statusBar,
          left: 12,
          right: 12),
      color: const Color(0xFF2E7D32),
      child: Row(
        children: [

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MenuPage()),
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
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          if (!isSearching)
            IconButton(
              icon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  isSearching = true;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [

          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search...",
                border: InputBorder.none,
              ),
              onSubmitted: (value) {
                widget.onSearch(value);
              },
            ),
          ),

          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: const Color(0xFF2E7D32),
            ),
            onPressed: () {
              GlobalSearchHandler.startVoice(
                context,
                    (result) {
                  widget.onSearch(result);
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
            },
          ),

          IconButton(
            icon: const Icon(Icons.close),
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
}