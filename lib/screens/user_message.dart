import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_repository.dart';
import 'conversation_thread_panel.dart';
import 'message_conversation_page.dart';
import 'nearby_assist_map.dart';

class UserMessagePage extends StatefulWidget {
  const UserMessagePage({super.key, this.initialThreadId});

  final String? initialThreadId;

  @override
  State<UserMessagePage> createState() => _UserMessagePageState();
}

class _UserMessagePageState extends State<UserMessagePage> {
  final ImagePicker _imagePicker = ImagePicker();
  String _driverName = 'EV Driver';
  bool _openedInitialThread = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadDriverName();
    AppRepository.markInboxRead('driver');
  }

  Future<void> _loadDriverName() async {
    final profile = await AppRepository.getCurrentUserProfile();
    if (!mounted || profile == null) {
      return;
    }

    setState(() {
      _driverName =
          profile['fullName']?.toString() ??
          profile['username']?.toString() ??
          _driverName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamUserConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <Map<String, dynamic>>[];

        if (!_openedInitialThread && widget.initialThreadId != null) {
          final initialConversation = conversations.where((conversation) {
            return conversation['thread_id']?.toString() ==
                widget.initialThreadId;
          });
          if (initialConversation.isNotEmpty) {
            _openedInitialThread = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _openConversation(initialConversation.first);
            });
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            title: const Text('Chats', style: TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                onPressed: _showAssistOptions,
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return _buildWideLayout(conversations);
                }
                return _buildMobileList(conversations);
              },
            ),
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
                _buildEmergencyBanner(),
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
                        currentSenderRole: 'driver',
                        currentSenderName: _driverName,
                        onSend: (text) {
                          return AppRepository.sendConversationMessage(
                            threadId: selected['thread_id']?.toString() ?? '',
                            senderRole: 'driver',
                            senderName: _driverName,
                            text: text,
                          );
                        },
                        onPickImage: () => _pickVehicleImage(
                          selected['thread_id']?.toString() ?? '',
                        ),
                        isUploadingImage: _isUploadingImage,
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
          child: _buildEmergencyBanner(),
        ),
        Expanded(child: _buildConversationList(conversations)),
      ],
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
          key: ValueKey(threadId),
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
                      child: Icon(
                        _conversationIcon(conversation),
                        color: const Color(0xFF2E7D32),
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
                                  conversation['responder_name']?.toString() ??
                                      'Support',
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
                            '${conversation['issue_label']?.toString() ?? 'Assistance'} · ${conversation['location_name']?.toString() ?? 'Unknown location'}',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700,
                              height: 1.3,
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

  Widget _buildEmergencyBanner() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamAlerts(),
      builder: (context, snapshot) {
        final alerts = (snapshot.data ?? const <Map<String, dynamic>>[]).where((
          alert,
        ) {
          final sameUser = alert['user_id'] == AppRepository.currentUserId;
          final level = ((alert['impact_level'] ?? 0) as num).toInt();
          return sameUser && level >= 4;
        }).toList();

        final hasSevereAlert = alerts.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasSevereAlert
                ? const Color(0xFFFFF4E5)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasSevereAlert
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFF81C784),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasSevereAlert ? Icons.warning_amber_rounded : Icons.chat,
                color: hasSevereAlert
                    ? const Color(0xFFEF6C00)
                    : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasSevereAlert
                      ? 'Level 4 and Level 5 crashes are already auto-forwarded to the hospital dashboard. You can still message nearby hospitals or EV technicians here for manual follow-up.'
                      : 'Press + to connect with nearby hospitals or EV technicians.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
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
              'Use the + button to connect with Health Assist or Technician Assist chatbot support.',
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
          currentSenderRole: 'driver',
          currentSenderName: _driverName,
        ),
      ),
    );
    if (mounted) {
      AppRepository.markInboxRead('driver');
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

  Future<void> _pickVehicleImage(String threadId) async {
    if (threadId.isEmpty || _isUploadingImage) {
      return;
    }

    final source = await _chooseImageSource();
    if (source == null) {
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      await AppRepository.sendConversationImage(
        threadId: threadId,
        senderRole: 'driver',
        senderName: _driverName,
        imageBase64: base64Encode(bytes),
      );
      if (mounted) {
        AppRepository.markInboxRead('driver');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle condition image sent to the conversation.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send vehicle condition photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share a fresh camera photo or choose an existing image for hospital or technician review.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo now'),
                  subtitle: const Text('Best for accident or damage proof'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  subtitle: const Text('Use an existing car condition image'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAssistOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'What do you need?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  'Choose the support you want to connect with right now.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 20),
                _assistButton(
                  icon: Icons.local_hospital,
                  label: 'Health Assist',
                  subtitle:
                      'Search nearby hospitals and clinics, then message or call them.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyAssistMapPage(
                          assistType: AssistType.health,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _assistButton(
                  icon: Icons.build_circle_outlined,
                  label: 'Technician Assist',
                  subtitle:
                      'Find nearby EV technicians and continue with an AI workshop assistant in this inbox.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NearbyAssistMapPage(
                          assistType: AssistType.technician,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _assistButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(icon, color: const Color(0xFF2E7D32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _conversationIcon(Map<String, dynamic> conversation) {
    final role = conversation['responder_role']?.toString();
    return role == 'hospital' ? Icons.support_agent : Icons.build_circle;
  }

  String _formatTimestamp(Object? value) {
    final date = AppRepository.parseTimestamp(value);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
