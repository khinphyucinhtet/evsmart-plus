import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_repository.dart';
import 'conversation_thread_panel.dart';

class MessageConversationPage extends StatefulWidget {
  const MessageConversationPage({
    super.key,
    required this.conversation,
    required this.currentSenderRole,
    required this.currentSenderName,
  });

  final Map<String, dynamic> conversation;
  final String currentSenderRole;
  final String currentSenderName;

  @override
  State<MessageConversationPage> createState() =>
      _MessageConversationPageState();
}

class _MessageConversationPageState extends State<MessageConversationPage> {
  final Set<String> _selectedMessageIds = <String>{};
  final ImagePicker _imagePicker = ImagePicker();
  bool _isDeleting = false;
  bool _isUploadingImage = false;

  List<String> _quickRepliesFor(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> conversation,
  ) {
    if (widget.currentSenderRole != 'driver' || messages.isEmpty) {
      return const <String>[];
    }

    Map<String, dynamic>? latestResponderMessage;
    for (final message in messages.reversed) {
      final senderRole = message['sender_role']?.toString() ?? '';
      if (senderRole != 'driver' && senderRole != 'system') {
        latestResponderMessage = message;
        break;
      }
    }

    if (latestResponderMessage == null) {
      return const <String>[];
    }

    final text = latestResponderMessage['text']?.toString().toLowerCase() ?? '';
    final locationName =
        conversation['location_name']?.toString() ?? 'my current location';

    if (text.contains('tap yes or no below') ||
        text.contains('correct pickup point')) {
      return const <String>['Yes', 'No'];
    }
    if (text.contains('send the exact pickup location') ||
        text.contains('send the location')) {
      return <String>['Use current location', 'Location: $locationName'];
    }
    if (text.contains('send a dashboard photo')) {
      return const <String>['Battery warning is on', 'The EV is fully dead'];
    }
    return const <String>[];
  }

  @override
  void initState() {
    super.initState();
    AppRepository.markInboxRead(widget.currentSenderRole);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.currentSenderRole == 'driver'
        ? widget.conversation['responder_name']?.toString() ?? 'Messages'
        : widget.conversation['driver_name']?.toString() ?? 'Messages';
    final threadId = widget.conversation['thread_id']?.toString() ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamConversationMessages(threadId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <Map<String, dynamic>>[];
        final quickReplies = _quickRepliesFor(messages, widget.conversation);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2E7D32),
            title: Text(
              _selectedMessageIds.isEmpty
                  ? title
                  : '${_selectedMessageIds.length} selected',
              style: const TextStyle(color: Colors.white),
            ),
            actions: _selectedMessageIds.isEmpty
                ? null
                : [
                    IconButton(
                      tooltip: 'Select all',
                      onPressed: messages.isEmpty
                          ? null
                          : () => _selectAll(messages),
                      icon: const Icon(Icons.select_all, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Delete selected',
                      onPressed: _isDeleting
                          ? null
                          : () => _deleteSelected(messages),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
          ),
          body: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
              ),
              child: ConversationThreadPanel(
                conversation: widget.conversation,
                messages: messages,
                currentSenderRole: widget.currentSenderRole,
                currentSenderName: widget.currentSenderName,
                onSend: (text) async {
                  await AppRepository.sendConversationMessage(
                    threadId: threadId,
                    senderRole: widget.currentSenderRole,
                    senderName: widget.currentSenderName,
                    text: text,
                  );
                  if (mounted) {
                    AppRepository.markInboxRead(widget.currentSenderRole);
                  }
                },
                onPickImage: widget.currentSenderRole == 'driver'
                    ? _pickVehicleImage
                    : null,
                isUploadingImage: _isUploadingImage,
                quickReplies: quickReplies,
                onQuickReply: (value) async {
                  final outgoingText = switch (value) {
                    'Yes' => 'Yes, use my current location.',
                    'No' => 'No, the pickup location is different.',
                    'Use current location' => 'Use my current location.',
                    _ => value,
                  };
                  await AppRepository.sendConversationMessage(
                    threadId: threadId,
                    senderRole: widget.currentSenderRole,
                    senderName: widget.currentSenderName,
                    text: outgoingText,
                  );
                  if (mounted) {
                    AppRepository.markInboxRead(widget.currentSenderRole);
                  }
                },
                accentColor: const Color(0xFF2E7D32),
                emptyTitle: 'No conversation selected',
                emptySubtitle: 'Open a message thread from the inbox.',
                selectionMode: _selectedMessageIds.isNotEmpty,
                selectedMessageIds: _selectedMessageIds,
                onToggleSelection: _toggleSelection,
              ),
            ),
          ),
          bottomNavigationBar: _selectedMessageIds.isEmpty
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearSelection,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isDeleting
                                ? null
                                : () => _deleteSelected(messages),
                            child: Text(
                              _isDeleting ? 'Deleting...' : 'Delete selected',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> messages) {
    setState(() {
      _selectedMessageIds
        ..clear()
        ..addAll(
          messages
              .map((message) => message['message_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
    });
  }

  Future<void> _pickVehicleImage() async {
    final threadId = widget.conversation['thread_id']?.toString() ?? '';
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
        senderRole: widget.currentSenderRole,
        senderName: widget.currentSenderName,
        imageBase64: base64Encode(bytes),
      );
      if (mounted) {
        AppRepository.markInboxRead(widget.currentSenderRole);
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

  Future<void> _deleteSelected(List<Map<String, dynamic>> messages) async {
    if (_selectedMessageIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete selected messages?'),
          content: Text(
            'This will remove ${_selectedMessageIds.length} message(s) from the conversation log.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final deleteAll = messages.length == _selectedMessageIds.length;
    setState(() => _isDeleting = true);
    try {
      await AppRepository.deleteConversationMessages(
        widget.conversation['thread_id']?.toString() ?? '',
        _selectedMessageIds.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedMessageIds.clear();
      });
      if (deleteAll && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
