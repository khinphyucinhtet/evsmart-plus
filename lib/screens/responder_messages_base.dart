import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import 'conversation_thread_panel.dart';
import 'message_conversation_page.dart';

class ResponderMessagesPage extends StatefulWidget {
  const ResponderMessagesPage({
    super.key,
    required this.role,
    required this.title,
    required this.emptySubtitle,
  });

  final String role;
  final String title;
  final String emptySubtitle;

  @override
  State<ResponderMessagesPage> createState() => _ResponderMessagesPageState();
}

class _ResponderMessagesPageState extends State<ResponderMessagesPage> {
  String _senderName = 'Responder';

  @override
  void initState() {
    super.initState();
    _loadSenderName();
    AppRepository.markInboxRead(widget.role);
  }

  Future<void> _loadSenderName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    if (widget.role == 'hospital') {
      final profile = await AppRepository.getProfileByPath(
        AppRepository.ambulanceProfilesRef,
        uid,
      );
      if (!mounted || profile == null) {
        return;
      }
      setState(() {
        _senderName =
            profile['driver_name']?.toString() ??
            profile['hospital_name']?.toString() ??
            'Ambulance Driver';
      });
      return;
    }

    final profile = await AppRepository.getProfileByPath(
      AppRepository.technicianProfilesRef,
      uid,
    );
    if (!mounted || profile == null) {
      return;
    }
    setState(() {
      _senderName =
          profile['technician_name']?.toString() ??
          profile['company_name']?.toString() ??
          'EV Technician';
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamRoleConversations(widget.role),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <Map<String, dynamic>>[];

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            title: Text(widget.title, style: const TextStyle(color: Colors.white)),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _buildWideLayout(conversations);
              }
              return _buildMobileList(conversations);
            },
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(List<Map<String, dynamic>> conversations) {
    final selected = conversations.isEmpty ? null : conversations.first;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 360,
            child: Column(
              children: [
                _buildSummaryCard(conversations.length),
                const SizedBox(height: 14),
                Expanded(child: _buildConversationList(conversations)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: selected == null
                ? _buildEmptyState()
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: AppRepository.streamConversationMessages(
                      selected['thread_id']?.toString() ?? '',
                    ),
                    builder: (context, snapshot) {
                      final messages =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      return ConversationThreadPanel(
                        conversation: selected,
                        messages: messages,
                        currentSenderRole: widget.role,
                        currentSenderName: _senderName,
                        onSend: (text) {
                          return AppRepository.sendConversationMessage(
                            threadId: selected['thread_id']?.toString() ?? '',
                            senderRole: widget.role,
                            senderName: _senderName,
                            text: text,
                          );
                        },
                        emptyTitle: 'No active driver chat',
                        emptySubtitle: widget.emptySubtitle,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> conversations) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: _buildSummaryCard(conversations.length),
        ),
        Expanded(
          child: _buildConversationList(conversations),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '$count live conversations',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.role == 'hospital'
                ? 'Tap any driver chat to coordinate emergency response.'
                : 'Tap any driver chat to continue EV repair support.',
            style: const TextStyle(height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(List<Map<String, dynamic>> conversations) {
    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final threadId = conversation['thread_id']?.toString() ?? '';

        return Dismissible(
          key: ValueKey('${widget.role}_$threadId'),
          direction: DismissDirection.endToStart,
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(threadId),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _openConversation(conversation),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE8F5E9),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation['driver_name']?.toString() ??
                                      'EV Driver',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimestamp(conversation['updated_at']),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            conversation['location_name']?.toString() ??
                                'Unknown location',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            conversation['last_message']?.toString() ??
                                'Conversation created',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_chat_unread_outlined,
              size: 44,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'No active chats yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageConversationPage(
          conversation: conversation,
          currentSenderRole: widget.role,
          currentSenderName: _senderName,
        ),
      ),
    );
    if (mounted) {
      AppRepository.markInboxRead(widget.role);
    }
  }

  Future<bool?> _confirmDelete(String threadId) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete chat log?'),
          content: const Text(
            'This permanently deletes the conversation from Firebase for all roles.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await AppRepository.deleteConversationThread(threadId);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(Object? value) {
    final date = AppRepository.parseTimestamp(value);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
