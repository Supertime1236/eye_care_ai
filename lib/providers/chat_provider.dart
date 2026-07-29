import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.isTyping = false});

  final String text;
  final bool isUser;
  final bool isTyping;
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  bool isTyping = false;
  bool greeted = false;

  void addMessage(ChatMessage message) {
    messages.add(message);
    notifyListeners();
  }

  void addUserMessage(String text) {
    messages.add(ChatMessage(text: text.trim(), isUser: true));
    notifyListeners();
  }

  void addBotMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  void setTyping(bool value) {
    isTyping = value;
    notifyListeners();
  }

  void markGreeted() {
    greeted = true;
    notifyListeners();
  }

  void clearMessages() {
    messages.clear();
    greeted = false;
    isTyping = false;
    notifyListeners();
  }

  // Chuyển lịch sử hội thoại hiện có (bỏ qua bong bóng "đang gõ...") sang
  // đúng định dạng Anthropic Messages API để gửi lên EyeChatService, giữ
  // ngữ cảnh nhiều lượt hỏi-đáp thay vì chỉ gửi mỗi câu hỏi mới nhất.
  List<Map<String, String>> toApiHistory() {
    return messages
        .where((m) => !m.isTyping && m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
  }
}
