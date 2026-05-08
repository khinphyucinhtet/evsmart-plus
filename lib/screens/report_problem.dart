import 'package:flutter/material.dart';

import 'alert.dart';
import 'charge.dart';
import 'user_message.dart';
import 'view_profile.dart';

class QuickReply {
  const QuickReply({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.quickReplies,
    this.customWidget,
  });

  final String text;
  final bool isUser;
  final List<QuickReply>? quickReplies;
  final Widget? customWidget;
  final DateTime time;
}

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  static const Color _primaryGreen = Color(0xFF1E7E34);
  static const Color _secondaryGreen = Color(0xFF2BA24C);
  static const Color _backgroundColor = Color(0xFFF6F8F7);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textColor = Color(0xFF1F2937);
  static const Color _greyText = Color(0xFF6B7280);

  final List<ChatMessage> _messages = <ChatMessage>[];
  final List<Map<String, dynamic>> _submittedReports = <Map<String, dynamic>>[];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  int _reportCounter = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(
    String text, {
    List<QuickReply>? quickReplies,
    Widget? customWidget,
  }) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: false,
          quickReplies: quickReplies,
          customWidget: customWidget,
          time: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, time: DateTime.now()),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 260,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleSend() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _controller.clear();
    _addUserMessage(text);
    _handleUserInput(text);
  }

  void _handleUserInput(String input) {
    final String normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    if (normalized == 'end') {
      _addBotMessage(
        'Thank you for using EVSmart+ Support.\nIf you need help again later, just open this page anytime. Stay safe on the road.',
      );
      return;
    }

    if (normalized == 'menu' || normalized == 'topics') {
      _addBotMessage(
        'Here are the popular topics again:',
        customWidget: _buildPopularTopicsGrid(),
      );
      return;
    }

    if (_containsAny(normalized, const <String>[
      'report',
      'problem',
      'bug',
      'issue',
      'crash',
    ])) {
      _openTopicFlow('report_problem', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>[
      'charging',
      'station',
      'map',
    ])) {
      _openTopicFlow('charging_help', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>[
      'technician',
      'repair',
      'service',
    ])) {
      _openTopicFlow('technician_connect', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>[
      'accident',
      'impact',
      'hospital',
      'ambulance',
      'emergency',
    ])) {
      _openTopicFlow('emergency_help', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>[
      'login',
      'password',
      'register',
      'account',
    ])) {
      _openTopicFlow('account_login', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>[
      'reward',
      'notification',
      'message',
    ])) {
      _openTopicFlow('general_help', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>['app crash', 'app crashes'])) {
      _handleQuickReply('App Crash', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>['feature not working'])) {
      _handleQuickReply('Feature Not Working', addUserBubble: false);
      return;
    }

    if (_containsAny(normalized, const <String>['slow performance', 'slow'])) {
      _handleQuickReply('Slow Performance', addUserBubble: false);
      return;
    }

    _addBotMessage(
      'I can help with reporting app issues, charging support, technician help, emergency actions, account access, and general EVSmart+ guidance.\nYou can type "menu" to see the topic cards again.',
      quickReplies: <QuickReply>[
        _reply('Report a Problem', () => _openTopicFlow('report_problem')),
        _reply('Charging Help', () => _openTopicFlow('charging_help')),
        _reply('Emergency Help', () => _openTopicFlow('emergency_help')),
      ],
    );
  }

  bool _containsAny(String value, List<String> keywords) {
    for (final String keyword in keywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  QuickReply _reply(String label, VoidCallback onTap, {IconData? icon}) {
    return QuickReply(label: label, icon: icon, onTap: onTap);
  }

  void _openTopicFlow(String topicId, {bool addUserBubble = true}) {
    switch (topicId) {
      case 'report_problem':
        if (addUserBubble) {
          _addUserMessage('I want to report a problem.');
        }
        _addBotMessage(
          'Sorry about that. Let’s report the issue properly so the EVSmart+ support team can check it.\nPlease choose the problem type first.',
          quickReplies: <QuickReply>[
            _reply('App Crash', () => _handleQuickReply('App Crash')),
            _reply(
              'Feature Not Working',
              () => _handleQuickReply('Feature Not Working'),
            ),
            _reply(
              'Slow Performance',
              () => _handleQuickReply('Slow Performance'),
            ),
            _reply('Charging Issue', () => _handleQuickReply('Charging Issue')),
            _reply('Alert Issue', () => _handleQuickReply('Alert Issue')),
            _reply('Other Issue', () => _handleQuickReply('Other Issue')),
          ],
        );
        break;
      case 'charging_help':
        if (addUserBubble) {
          _addUserMessage('I need charging help.');
        }
        _addBotMessage(
          'Here are nearby charging options based on your current area:',
          customWidget: Column(
            children: <Widget>[
              _buildChargingStationCard(
                name: 'EV Hub Station',
                distance: '1.2 km',
                available: '7 / 12',
              ),
              const SizedBox(height: 12),
              _buildChargingStationCard(
                name: 'GreenCharge Point',
                distance: '2.4 km',
                available: '4 / 8',
              ),
            ],
          ),
        );
        break;
      case 'technician_connect':
        if (addUserBubble) {
          _addUserMessage('I need a technician.');
        }
        _addBotMessage(
          'Here are nearby technicians available for EV support:',
          customWidget: Column(
            children: <Widget>[
              _buildTechnicianCard(
                name: 'EV Tech Pro',
                rating: '4.8',
                distance: '1.3 km',
                status: 'Available',
              ),
              const SizedBox(height: 12),
              _buildTechnicianCard(
                name: 'Green Auto Care',
                rating: '4.6',
                distance: '2.1 km',
                status: 'Available',
              ),
            ],
          ),
        );
        break;
      case 'emergency_help':
        if (addUserBubble) {
          _addUserMessage('I need emergency help.');
        }
        _addBotMessage(
          'I’m here to help. Please confirm your situation:',
          customWidget: _buildEmergencyOptions(),
        );
        break;
      case 'account_login':
        if (addUserBubble) {
          _addUserMessage('I need account help.');
        }
        _addBotMessage(
          'No worries. I can help with account access.\nChoose an option:',
          quickReplies: <QuickReply>[
            _reply(
              'Reset via Email',
              () => _handleQuickReply('Reset via Email'),
            ),
            _reply(
              'Change Password',
              () => _handleQuickReply('Change Password'),
            ),
            _reply('Login Problem', () => _handleQuickReply('Login Problem')),
            _reply('Register Issue', () => _handleQuickReply('Register Issue')),
          ],
        );
        break;
      case 'general_help':
        if (addUserBubble) {
          _addUserMessage('I need general help.');
        }
        _addBotMessage(
          'EVSmart+ can help you with:\n'
          '1. EV battery and sensor monitoring\n'
          '2. Charging station finder\n'
          '3. Manual alert reporting\n'
          '4. Emergency notification\n'
          '5. Technician and hospital messaging\n'
          '6. Rewards and donation points',
          quickReplies: <QuickReply>[
            _reply('Back to Topics', () => _handleQuickReply('Back to Topics')),
            _reply(
              'Report a Problem',
              () => _handleQuickReply('Report a Problem'),
            ),
            _reply(
              'Contact Support',
              () => _handleQuickReply('Contact Support'),
            ),
          ],
        );
        break;
    }
  }

  void _handleQuickReply(String label, {bool addUserBubble = true}) {
    if (addUserBubble) {
      _addUserMessage(label);
    }

    switch (label) {
      case 'App Crash':
      case 'Feature Not Working':
      case 'Slow Performance':
      case 'Charging Issue':
      case 'Alert Issue':
      case 'Other Issue':
        _addBotMessage(
          'Got it. Please describe what happened below. You can type the issue or use the microphone button if voice input is available.',
          customWidget: _buildReportFormCard(initialProblemType: label),
        );
        break;
      case 'Reset via Email':
        _addBotMessage(
          'Go to Login page > Forgot Password > enter your email > Reset via Email.',
        );
        break;
      case 'Change Password':
        _addBotMessage(
          'Go to Menu > Change Password. Use at least 6 characters.',
        );
        break;
      case 'Login Problem':
        _addBotMessage(
          'Check your username/password, internet connection, and whether your account exists.',
        );
        break;
      case 'Register Issue':
        _addBotMessage(
          'Use a new email and unique username. If username already exists, choose another one.',
        );
        break;
      case 'Send Ambulance':
        _addBotMessage(
          'Ambulance support request prepared.\nFor serious Level 4–5 impact cases, the nearest hospital and ambulance dashboard will receive the alert with your location.',
        );
        break;
      case 'Nearby Hospital':
        _addBotMessage(
          'Nearest hospitals based on your current location:\n'
          '1. KPJ Selangor Specialist Hospital\n'
          '2. Avisena Specialist Hospital\n'
          '3. Shah Alam Hospital',
          quickReplies: <QuickReply>[
            _reply(
              'Open Emergency Alert Page',
              () => _handleQuickReply('Open Emergency Alert Page'),
              icon: Icons.open_in_new_rounded,
            ),
          ],
        );
        break;
      case 'Call Emergency':
        _addBotMessage(
          'If this is life-threatening, call emergency services immediately.\nYou can also open the EVSmart+ Alert page to trigger a manual emergency workflow.',
          quickReplies: <QuickReply>[
            _reply(
              'Open Emergency Alert Page',
              () => _handleQuickReply('Open Emergency Alert Page'),
            ),
          ],
        );
        break;
      case 'Manual Alert Level':
        _addBotMessage(
          'Choose a manual alert level:',
          customWidget: _buildAlertLevelButtons(),
        );
        break;
      case 'Open Emergency Alert Page':
        _safeNavigate(
          '/alert',
          'The Alert page is not linked yet. Please connect this button to your actual alert page route.',
        );
        break;
      case 'Back to Topics':
        _addBotMessage(
          'Here are the popular topics again:',
          customWidget: _buildPopularTopicsGrid(),
        );
        break;
      case 'Report a Problem':
        _openTopicFlow('report_problem');
        break;
      case 'Contact Support':
        _addBotMessage(
          'You can submit a detailed issue using Report a Problem.\nFor urgent safety cases, please use Emergency Help.',
          quickReplies: <QuickReply>[
            _reply('Report a Problem', () => _openTopicFlow('report_problem')),
            _reply('Emergency Help', () => _openTopicFlow('emergency_help')),
          ],
        );
        break;
      case 'Charging Help':
        _openTopicFlow('charging_help');
        break;
      case 'Emergency Help':
        _openTopicFlow('emergency_help');
        break;
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      decoration: const BoxDecoration(
        color: _primaryGreen,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          const Expanded(
            child: Text(
              'EVSmart+ Support',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _showQuickActionSheet,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      itemCount: _messages.length + 2,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _buildWelcomeMessage();
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _buildPopularTopicsGrid(),
          );
        }
        return _buildMessageBubble(_messages[index - 2]);
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildBotAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'Hello 👋\n'
              'Welcome to EVSmart+ Support.\n'
              'I’m your smart assistant.\n'
              'How can I help you today?',
              style: TextStyle(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularTopicsGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double aspectRatio = width < 360 ? 1.02 : 1.10;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                'Popular Topics',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GridView.builder(
              itemCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: aspectRatio,
              ),
              itemBuilder: (BuildContext context, int index) {
                switch (index) {
                  case 0:
                    return _buildTopicCard(
                      title: 'Report a Problem',
                      subtitle: 'App, charging, or feature issue',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFE53935),
                      iconTint: const Color(0xFFFFF1F1),
                      onTap: () => _openTopicFlow('report_problem'),
                    );
                  case 1:
                    return _buildTopicCard(
                      title: 'Charging Help',
                      subtitle: 'Stations, map, or availability',
                      icon: Icons.ev_station_rounded,
                      iconColor: _primaryGreen,
                      iconTint: const Color(0xFFEFFAF2),
                      onTap: () => _openTopicFlow('charging_help'),
                    );
                  case 2:
                    return _buildTopicCard(
                      title: 'Technician Connect',
                      subtitle: 'Nearby EV support',
                      icon: Icons.build_rounded,
                      iconColor: const Color(0xFF7E57C2),
                      iconTint: const Color(0xFFF4EFFF),
                      onTap: () => _openTopicFlow('technician_connect'),
                    );
                  case 3:
                    return _buildTopicCard(
                      title: 'Emergency Help',
                      subtitle: 'Impact or urgent alert',
                      icon: Icons.notification_important_rounded,
                      iconColor: const Color(0xFFD32F2F),
                      iconTint: const Color(0xFFFFF2F1),
                      onTap: () => _openTopicFlow('emergency_help'),
                    );
                  case 4:
                    return _buildTopicCard(
                      title: 'Account & Login',
                      subtitle: 'Password or profile help',
                      icon: Icons.person_rounded,
                      iconColor: const Color(0xFF1976D2),
                      iconTint: const Color(0xFFF1F7FF),
                      onTap: () => _openTopicFlow('account_login'),
                    );
                  default:
                    return _buildTopicCard(
                      title: 'General Help',
                      subtitle: 'Other app questions',
                      icon: Icons.help_outline_rounded,
                      iconColor: const Color(0xFFF9A825),
                      iconTint: const Color(0xFFFFF8E8),
                      onTap: () => _openTopicFlow('general_help'),
                    );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopicCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconTint,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _greyText,
                    fontSize: 11.6,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final bool isUser = message.isUser;
    final BorderRadius bubbleRadius = BorderRadius.circular(20);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: isUser ? 52 : 0,
            right: isUser ? 0 : 20,
          ),
          child: isUser
              ? Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: bubbleRadius,
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.2,
                      fontWeight: FontWeight.w600,
                      height: 1.52,
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildBotAvatar(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (message.text.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: bubbleRadius,
                                boxShadow: const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x10000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                message.text,
                                style: const TextStyle(
                                  color: _textColor,
                                  fontSize: 14.2,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          if (message.customWidget != null) ...<Widget>[
                            if (message.text.isNotEmpty)
                              const SizedBox(height: 10),
                            message.customWidget!,
                          ],
                          if (message.quickReplies != null &&
                              message.quickReplies!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            _buildQuickReplies(message.quickReplies!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _primaryGreen.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.smart_toy_rounded,
        color: _primaryGreen,
        size: 18,
      ),
    );
  }

  Widget _buildQuickReplies(List<QuickReply> quickReplies) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickReplies.map((QuickReply reply) {
        return ActionChip(
          onPressed: reply.onTap,
          backgroundColor: Colors.white,
          side: BorderSide(
            color:
                reply.label.contains('Ambulance') ||
                    reply.label.contains('Emergency')
                ? const Color(0xFFF1C0BD)
                : const Color(0xFFD6E9DA),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          avatar: reply.icon == null
              ? null
              : Icon(reply.icon, size: 16, color: _primaryGreen),
          label: Text(
            reply.label,
            style: TextStyle(
              color:
                  reply.label.contains('Ambulance') ||
                      reply.label.contains('Emergency')
                  ? const Color(0xFFD32F2F)
                  : _primaryGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12.8,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            _buildCircleInputButton(
              icon: Icons.add_rounded,
              onTap: _showQuickActionSheet,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: _greyText, fontSize: 14),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildCircleInputButton(
              icon: _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              onTap: _handleMicTap,
              outlined: true,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _handleSend,
                style: FilledButton.styleFrom(
                  backgroundColor: _secondaryGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleInputButton({
    required IconData icon,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    final Widget child = Icon(icon, color: _primaryGreen, size: 20);
    if (outlined) {
      return SizedBox(
        width: 40,
        height: 40,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD5E8D9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: EdgeInsets.zero,
          ),
          child: child,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _primaryGreen.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildReportFormCard({required String initialProblemType}) {
    return _ProblemReportFormCard(
      initialProblemType: initialProblemType,
      onSubmit: (Map<String, dynamic> report) {
        final String referenceId =
            'EVS-${DateTime.now().year}-${_reportCounter.toString().padLeft(4, '0')}';
        _reportCounter += 1;

        final Map<String, dynamic> payload = <String, dynamic>{
          ...report,
          'referenceId': referenceId,
          'submittedAt': DateTime.now().toIso8601String(),
        };

        setState(() {
          _submittedReports.add(payload);
        });

        debugPrint('Support report submitted: $payload');
        // TODO: Save report to Firebase under support_reports collection.

        _addBotMessage(
          'Your report has been submitted successfully ✅\n\n'
          'Reference ID: $referenceId\n\n'
          'Our application support team will review it.\n'
          'If it is urgent, please also use Emergency Help or Manual Alert.',
          quickReplies: <QuickReply>[
            _reply('Back to Topics', () => _handleQuickReply('Back to Topics')),
            _reply('Emergency Help', () => _handleQuickReply('Emergency Help')),
            _reply('Charging Help', () => _handleQuickReply('Charging Help')),
          ],
        );
      },
      onCancel: () {
        _addBotMessage(
          'No problem. You can choose another topic anytime.',
          quickReplies: <QuickReply>[
            _reply('Back to Topics', () => _handleQuickReply('Back to Topics')),
          ],
        );
      },
    );
  }

  Widget _buildChargingStationCard({
    required String name,
    required String distance,
    required String available,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAE4)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: _primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 14.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Distance: $distance',
                      style: const TextStyle(
                        color: _greyText,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBF8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Available',
                    style: TextStyle(
                      color: _greyText,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  available,
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _safeNavigate(
                    '/charge',
                    'The Charge page is not linked yet. Please connect this button to your actual charging page route.',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: const BorderSide(color: Color(0xFFB7DFC1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Open Map',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _safeNavigate(
                    '/charge',
                    'The Charge page is not linked yet. Please connect this button to your actual charging page route.',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'View More Stations',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianCard({
    required String name,
    required String rating,
    required String distance,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAE4)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.build_rounded,
                  color: Color(0xFF7E57C2),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 14.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rating: $rating',
                      style: const TextStyle(
                        color: _greyText,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                distance,
                style: const TextStyle(
                  color: _greyText,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.4,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  _addBotMessage(
                    'Calling is a demo action for now. In the real app, this can open the phone dialer.',
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryGreen,
                  side: const BorderSide(color: Color(0xFFB7DFC1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Call',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _safeNavigate(
                  '/messages',
                  'The Messages page is not linked yet. Please connect this button to your actual messaging route.',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildEmergencyButton(
          label: 'Send Ambulance',
          outlined: true,
          danger: true,
          onTap: () => _handleQuickReply('Send Ambulance'),
        ),
        const SizedBox(height: 8),
        _buildEmergencyButton(
          label: 'Nearby Hospital',
          outlined: true,
          onTap: () => _handleQuickReply('Nearby Hospital'),
        ),
        const SizedBox(height: 8),
        _buildEmergencyButton(
          label: 'Call Emergency',
          outlined: true,
          onTap: () => _handleQuickReply('Call Emergency'),
        ),
        const SizedBox(height: 8),
        _buildEmergencyButton(
          label: 'Manual Alert Level',
          onTap: () => _handleQuickReply('Manual Alert Level'),
        ),
      ],
    );
  }

  Widget _buildEmergencyButton({
    required String label,
    required VoidCallback onTap,
    bool outlined = false,
    bool danger = false,
  }) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? const Color(0xFFD32F2F) : _primaryGreen,
          side: BorderSide(
            color: danger ? const Color(0xFFF1C0BD) : const Color(0xFFB7DFC1),
          ),
          backgroundColor: danger ? const Color(0xFFFFF5F4) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }

    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildAlertLevelButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(5, (int index) {
        final int level = index + 1;
        return SizedBox(
          width: 48,
          child: OutlinedButton(
            onPressed: () {
              _addUserMessage('Level $level');
              if (level <= 3) {
                _addBotMessage(
                  'Level $level alert recorded as a minor/moderate issue. It can be sent to service support, insurance record, or nearby technician assistance.',
                );
              } else {
                _addBotMessage(
                  'Level $level emergency alert prepared. Hospital and ambulance dashboard will receive the alert with your current location.',
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: level >= 4
                  ? const Color(0xFFD32F2F)
                  : _primaryGreen,
              side: BorderSide(
                color: level >= 4
                    ? const Color(0xFFF1C0BD)
                    : const Color(0xFFB7DFC1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              '$level',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _safeNavigate(String routeName, String fallbackMessage) async {
    Widget? destination;

    switch (routeName) {
      case '/charge':
        destination = const ChargePage();
        break;
      case '/alert':
        destination = const AlertPage();
        break;
      case '/messages':
        destination = const UserMessagePage();
        break;
      case '/profile':
        destination = const ViewProfilePage();
        break;
    }

    if (destination != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination!));
      return;
    }

    try {
      // TODO: Replace placeholder route names with your actual named routes if needed.
      await Navigator.pushNamed(context, routeName);
    } catch (_) {
      _addBotMessage(fallbackMessage);
    }
  }

  void _showQuickActionSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildActionSheetItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Report Problem',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTopicFlow('report_problem');
                  },
                ),
                _buildActionSheetItem(
                  icon: Icons.ev_station_rounded,
                  label: 'Charging Help',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTopicFlow('charging_help');
                  },
                ),
                _buildActionSheetItem(
                  icon: Icons.notification_important_rounded,
                  label: 'Emergency Help',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTopicFlow('emergency_help');
                  },
                ),
                _buildActionSheetItem(
                  icon: Icons.build_rounded,
                  label: 'Technician Connect',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTopicFlow('technician_connect');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _primaryGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _greyText),
          ],
        ),
      ),
    );
  }

  void _handleMicTap() {
    setState(() {
      _isListening = !_isListening;
    });

    _addBotMessage(
      'Voice input is not enabled yet. Please install speech_to_text package.\n\n'
      'To enable voice input, add to pubspec.yaml:\n'
      'speech_to_text: ^7.0.0\n'
      'Then run flutter pub get.',
    );

    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _backgroundColor,
      body: Column(
        children: <Widget>[
          SafeArea(bottom: false, child: _buildHeader()),
          Expanded(child: _buildChatList()),
          SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildInputBar(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemReportFormCard extends StatefulWidget {
  const _ProblemReportFormCard({
    required this.initialProblemType,
    required this.onSubmit,
    required this.onCancel,
  });

  final String initialProblemType;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_ProblemReportFormCard> createState() => _ProblemReportFormCardState();
}

class _ProblemReportFormCardState extends State<_ProblemReportFormCard> {
  static const Color _primaryGreen = Color(0xFF1E7E34);
  static const Color _textColor = Color(0xFF1F2937);
  static const Color _greyText = Color(0xFF6B7280);

  late String _problemType;
  String _priority = 'Medium';
  final TextEditingController _screenController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String? _errorMessage;

  static const List<String> _problemTypes = <String>[
    'App Crash',
    'Feature Not Working',
    'Slow Performance',
    'Charging Issue',
    'Alert Issue',
    'Other Issue',
  ];

  static const List<String> _priorities = <String>[
    'Low',
    'Medium',
    'High',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    _problemType = widget.initialProblemType;
  }

  @override
  void dispose() {
    _screenController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_problemType.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Problem type and issue description are required before submitting.';
      });
      return;
    }

    widget.onSubmit(<String, dynamic>{
      'problemType': _problemType,
      'screenName': _screenController.text.trim(),
      'description': _descriptionController.text.trim(),
      'priority': _priority,
      'contact': _contactController.text.trim(),
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _greyText, fontSize: 12.6),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8E3)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Submit Problem Report',
            style: TextStyle(
              color: _textColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _problemType,
            decoration: _inputDecoration('Problem Type'),
            items: _problemTypes
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _problemType = value;
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _screenController,
            decoration: _inputDecoration(
              'Example: Charging page, Alert page, Login page',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 5,
            decoration: _inputDecoration('Describe what happened...'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: _inputDecoration('Priority'),
            items: _priorities
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() {
                _priority = value;
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contactController,
            decoration: _inputDecoration('Email or phone number'),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFD32F2F),
                fontSize: 12.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: const BorderSide(color: Color(0xFFB7DFC1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
