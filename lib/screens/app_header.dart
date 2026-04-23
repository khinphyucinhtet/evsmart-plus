import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/app_repository.dart';
import 'global_search.dart';
import 'menu.dart';
import 'user_message.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({
    super.key,
    required this.onSearch,
    this.title = 'EVSmart+',
    this.onMessageTap,
    this.extraActions = const <Widget>[],
    this.showMessageIcon = true,
    this.messageBadgeRole = 'driver',
    this.messageBadgeUserId,
  });

  final Function(String) onSearch;
  final String title;
  final VoidCallback? onMessageTap;
  final List<Widget> extraActions;
  final bool showMessageIcon;
  final String? messageBadgeRole;
  final String? messageBadgeUserId;

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool isSearching = false;
  bool isListening = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;

    return Container(
      height: 75 + statusBar,
      padding: EdgeInsets.only(top: statusBar, left: 12, right: 12),
      color: const Color(0xFF2E7D32),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MenuPage()),
              );
            },
            child: const Icon(Icons.menu, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isSearching
                ? _buildSearchBar()
                : Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          if (!isSearching) ...[
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    isSearching = true;
                  });
                },
              ),
            ),
            if (widget.showMessageIcon)
              GestureDetector(
                onTap: widget.onMessageTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserMessagePage(),
                        ),
                      );
                    },
                child: StreamBuilder<int>(
                  stream: widget.messageBadgeRole == null || Firebase.apps.isEmpty
                      ? null
                      : AppRepository.streamUnreadBadgeCount(
                          widget.messageBadgeRole!,
                          userId: widget.messageBadgeUserId,
                        ),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          'assets/images/ic_message_icon.png',
                          width: 24,
                          height: 24,
                          color: Colors.white,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -5,
                            top: -6,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (widget.showMessageIcon) const SizedBox(width: 4),
            ...widget.extraActions,
            const SizedBox(width: 4),
          ],
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
                hintText: 'Search...',
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
                  setState(() => isListening = false);
                },
                () {
                  setState(() => isListening = true);
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
