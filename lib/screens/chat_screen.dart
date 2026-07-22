import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.isTyping = false});

  final String text;
  final bool isUser;
  final bool isTyping;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[
    ChatMessage(
      text:
          'Hi! I\'m your EyeCare AI assistant. Ask me anything about eye health, '
          'screen time, or vision care tips.',
      isUser: false,
    ),
  ];

  bool _isTyping = false;

  static const _quickPrompts = [
    'How to reduce eye strain?',
    'Best foods for eye health',
    '20-20-20 rule explained',
    'When to see an eye doctor?',
  ];

  static const _aiResponses = {
    'How to reduce eye strain?':
        'To reduce eye strain: follow the 20-20-20 rule (every 20 min, look 20 feet away for 20 sec), '
        'adjust screen brightness, use proper lighting, blink often, and take regular breaks. '
        'Keep your screen 20-26 inches from your eyes.',
    'Best foods for eye health':
        'Foods rich in lutein, zeaxanthin, omega-3, and vitamins A, C, E support eye health. '
        'Try leafy greens (spinach, kale), fatty fish (salmon), eggs, carrots, citrus fruits, '
        'and nuts. Stay hydrated too!',
    '20-20-20 rule explained':
        'The 20-20-20 rule: every 20 minutes of screen time, look at something 20 feet (6 meters) '
        'away for at least 20 seconds. This relaxes your eye muscles and reduces digital eye strain. '
        'Set a timer or use our break reminders!',
    'When to see an eye doctor?':
        'See an eye doctor if you experience: persistent blurred vision, eye pain, frequent headaches, '
        'double vision, flashes of light, or sudden vision changes. Adults should get a comprehensive '
        'eye exam every 1-2 years, or annually if you wear glasses/contacts.',
  };

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isTyping = true;
      _messages.add(ChatMessage(text: '', isUser: false, isTyping: true));
    });
    _controller.clear();
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final response = _aiResponses.entries
        .firstWhere(
          (e) => text.toLowerCase().contains(e.key.toLowerCase().split(' ').first),
          orElse: () => MapEntry(
            '',
            'That\'s a great question about eye health! Based on general guidelines, '
            'maintaining regular breaks, good lighting, and annual eye check-ups are key. '
            'Would you like specific tips on screen time, nutrition, or vision exercises?',
          ),
        )
        .value;

    if (!mounted) return;

    setState(() {
      _messages.removeLast();
      _messages.add(ChatMessage(text: response, isUser: false));
      _isTyping = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Assistant', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ActionChip(
                  label: Text(_quickPrompts[index]),
                  backgroundColor: AppColors.chatAccent.withValues(alpha: 0.08),
                  labelStyle: TextStyle(
                    color: AppColors.chatAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppColors.chatAccent.withValues(alpha: 0.2),
                  ),
                  onPressed: () => _sendMessage(_quickPrompts[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(message: msg);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about eye health...',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurface
                          : AppColors.border.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.chatAccent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _sendMessage(_controller.text),
                    borderRadius: BorderRadius.circular(14),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.chatAccent
              : (isDark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
        ),
        child: message.isTyping
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: TypingDots(),
              )
            : Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.isUser ? Colors.white : null,
                      height: 1.4,
                    ),
              ),
      ),
    );
  }
}
