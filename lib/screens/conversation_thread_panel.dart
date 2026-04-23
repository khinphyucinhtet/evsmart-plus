import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationThreadPanel extends StatefulWidget {
  const ConversationThreadPanel({
    super.key,
    required this.conversation,
    required this.messages,
    required this.currentSenderRole,
    required this.currentSenderName,
    required this.onSend,
    this.accentColor = const Color(0xFF2E7D32),
    this.emptyTitle = 'No conversation selected',
    this.emptySubtitle = 'Choose a thread to start chatting.',
    this.selectionMode = false,
    this.selectedMessageIds = const <String>{},
    this.onToggleSelection,
    this.onPickImage,
    this.isUploadingImage = false,
  });

  final Map<String, dynamic>? conversation;
  final List<Map<String, dynamic>> messages;
  final String currentSenderRole;
  final String currentSenderName;
  final Future<void> Function(String text) onSend;
  final Color accentColor;
  final String emptyTitle;
  final String emptySubtitle;
  final bool selectionMode;
  final Set<String> selectedMessageIds;
  final void Function(String messageId)? onToggleSelection;
  final Future<void> Function()? onPickImage;
  final bool isUploadingImage;

  @override
  State<ConversationThreadPanel> createState() =>
      _ConversationThreadPanelState();
}

class _ConversationThreadPanelState extends State<ConversationThreadPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    if (conversation == null) {
      return _emptyState();
    }

    final title = widget.currentSenderRole == 'driver'
        ? conversation['responder_name']?.toString() ?? 'Support team'
        : conversation['driver_name']?.toString() ?? 'EV Driver';
    final subtitle =
        '${conversation['issue_label']?.toString() ?? 'Emergency coordination'} • ${conversation['location_name']?.toString() ?? 'Unknown location'}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.accentColor.withValues(alpha: 0.12),
                  child: Icon(Icons.support_agent, color: widget.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
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
                if (!widget.selectionMode &&
                    widget.currentSenderRole == 'driver' &&
                    (conversation['responder_phone']?.toString().isNotEmpty ??
                        false))
                  IconButton(
                    tooltip: 'Call',
                    onPressed: () => _launchPhone(
                      conversation['responder_phone']?.toString() ?? '',
                    ),
                    icon: Icon(Icons.call, color: widget.accentColor),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation below.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          widget.messages[widget.messages.length - 1 - index];
                      final senderRole =
                          message['sender_role']?.toString() ?? 'system';
                      final isSystem = senderRole == 'system';
                      final isMine = senderRole == widget.currentSenderRole;
                      final messageId =
                          message['message_id']?.toString() ?? 'msg_$index';
                      final isSelected = widget.selectedMessageIds.contains(
                        messageId,
                      );

                      if (isSystem) {
                        return _messageWrapper(
                          messageId: messageId,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE8F5E9)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                  border: isSelected
                                      ? Border.all(
                                          color: widget.accentColor,
                                          width: 1.2,
                                        )
                                      : null,
                                ),
                                child: Text(
                                  message['text']?.toString() ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return _messageWrapper(
                        messageId: messageId,
                        child: Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFC8E6C9)
                                  : isMine
                                  ? widget.accentColor
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(18),
                              border: isSelected
                                  ? Border.all(
                                      color: widget.accentColor,
                                      width: 1.4,
                                    )
                                  : null,
                            ),
                            child: _messageBody(
                              message: message,
                              isMine: isMine,
                              isSelected: isSelected,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onPickImage != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 2),
                      child: SizedBox(
                        height: 48,
                        width: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF0F4F1),
                            foregroundColor: widget.accentColor,
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          onPressed:
                              widget.selectionMode ||
                                  widget.isUploadingImage ||
                                  _isSending
                              ? null
                              : widget.onPickImage,
                          child: widget.isUploadingImage
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: widget.accentColor,
                                  ),
                                )
                              : const Icon(Icons.photo_camera_outlined),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !widget.selectionMode,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: widget.selectionMode
                            ? 'Selection mode active'
                            : widget.onPickImage != null
                            ? 'Type a message or send a vehicle photo...'
                            : 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: widget.selectionMode || _isSending
                          ? null
                          : _send,
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBody({
    required Map<String, dynamic> message,
    required bool isMine,
    required bool isSelected,
  }) {
    final text = message['text']?.toString() ?? '';
    final isTyping = message['is_typing'] == true;
    final imageBase64 = message['image_base64']?.toString();
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;
    final foregroundColor = isMine && !isSelected
        ? Colors.white
        : Colors.black87;
    final secondaryColor = isMine && !isSelected
        ? Colors.white70
        : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMine)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              message['sender_name']?.toString() ?? '',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
          ),
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _buildImage(
              imageBase64,
              isMine: isMine,
              isSelected: isSelected,
            ),
          ),
          if (text.trim().isNotEmpty) const SizedBox(height: 8),
        ],
        if (text.trim().isNotEmpty)
          Text(
            text,
            style: TextStyle(
              color: isTyping ? Colors.grey.shade600 : foregroundColor,
              fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
              fontWeight: isTyping ? FontWeight.w600 : FontWeight.normal,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          _formatTimestamp(message['timestamp']),
          style: TextStyle(fontSize: 11, color: secondaryColor),
        ),
      ],
    );
  }

  Widget _buildImage(
    String? imageBase64, {
    required bool isMine,
    required bool isSelected,
  }) {
    try {
      final bytes = base64Decode(imageBase64!);
      return Image.memory(bytes, width: 260, height: 190, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMine && !isSelected ? Colors.white24 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Image could not be rendered',
          style: TextStyle(
            color: isMine && !isSelected ? Colors.white : Colors.black54,
          ),
        ),
      );
    }
  }

  Widget _messageWrapper({required String messageId, required Widget child}) {
    if (widget.onToggleSelection == null) {
      return child;
    }

    return GestureDetector(
      onLongPress: () => widget.onToggleSelection!(messageId),
      onTap: widget.selectionMode
          ? () => widget.onToggleSelection!(messageId)
          : null,
      child: child,
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Center(
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
              Text(
                widget.emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await widget.onSend(text);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  String _formatTimestamp(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
