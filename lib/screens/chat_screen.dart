import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/language_provider.dart';
import '../config/env.dart';
import '../services/eye_chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // BUG ĐÃ SỬA: trước đây đoạn "chào hỏi lần đầu" này nằm ngay trong
    // build() (gọi provider.addMessage() -> notifyListeners() giữa lúc
    // framework đang xây widget tree) -> ném lỗi "setState() or
    // markNeedsBuild() called during build" (đã thấy trong log trước đây).
    // Dời sang initState() + addPostFrameCallback để an toàn, chạy ĐÚNG 1
    // LẦN sau khi frame đầu tiên vẽ xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ChatProvider>();
      if (!provider.greeted) {
        final strings = context.read<LanguageProvider>().strings;
        provider.addMessage(ChatMessage(text: strings.chatGreeting, isUser: false));
        provider.markGreeted();
      }
    });
  }

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
    final provider = context.read<ChatProvider>();
    if (text.trim().isEmpty || provider.isTyping) return;
    final strings = context.read<LanguageProvider>().strings;

    // BUG BẢO MẬT ĐÃ SỬA: trước đây có 2 dòng print() in thẳng API key ra
    // logcat (ai đọc log qua USB/`adb logcat` đều thấy được key thật) — đã
    // xoá bỏ, không có lý do gì để log giá trị này kể cả lúc debug.
    if (Env.nimApiKey.isEmpty) {
      provider.addBotMessage(strings.chatErrorMissingKey);
      return;
    }

    provider.addUserMessage(text);
    provider.setTyping(true);
    provider.addMessage(ChatMessage(text: '', isUser: false, isTyping: true));
    _controller.clear();
    _scrollToBottom();

    // STREAMING: nối từng mẩu chữ vào bong bóng chat ngay khi model sinh ra,
    // thay vì đợi trả lời xong hết mới hiện 1 lần -> cảm giác nhanh hơn hẳn.
    var receivedAnyChunk = false;
    try {
      await for (final delta in EyeChatService.instance.sendMessageStream(
        history: provider.toApiHistory(),
      )) {
        receivedAnyChunk = true;
        provider.appendToLastMessage(delta);
        _scrollToBottom();
      }
    } catch (e) {
      final message = e.toString();
      final String errorText;
      if (message.contains('invalid_api_key')) {
        errorText = strings.chatErrorInvalidKey;
      } else if (message.contains('rate_limited')) {
        errorText = strings.chatErrorRateLimited;
      } else if (message.contains('network_error')) {
        errorText = strings.chatErrorNetwork;
      } else {
        errorText = strings.chatErrorGeneric;
      }
      if (!mounted) return;
      if (receivedAnyChunk) {
        // Đã hiện được vài chữ rồi mới lỗi giữa chừng (mất mạng...) -> nối
        // thêm câu báo lỗi vào cuối thay vì xoá mất phần đã trả lời.
        provider.appendToLastMessage('\n\n⚠️ $errorText');
      } else {
        provider.messages.removeLast();
        provider.addBotMessage(errorText);
      }
      provider.setTyping(false);
      _scrollToBottom();
      return;
    }

    if (!mounted) return;
    provider.setTyping(false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    final quickPrompts = strings.chatQuickPrompts;

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
                    gradient: AppTheme.gradientFor(Theme.of(context).colorScheme.primary),
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
                    Text(strings.aiAssistant, style: Theme.of(context).textTheme.titleMedium),
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
                          strings.online,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox.shrink(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ActionChip(
                  label: Text(quickPrompts[index]),
                  backgroundColor: AppColors.chatAccent.withValues(alpha: 0.08),
                  labelStyle: TextStyle(
                    color: AppColors.chatAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppColors.chatAccent.withValues(alpha: 0.2),
                  ),
                  onPressed: () => _sendMessage(quickPrompts[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final msg = provider.messages[index];
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
                      hintText: strings.askAboutEyeHealth,
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
                    onSubmitted: (text) => _sendMessage(text),
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