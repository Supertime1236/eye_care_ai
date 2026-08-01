import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.isTyping = false});

  String text;
  final bool isUser;
  bool isTyping;
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

  // Nối thêm 1 mẩu chữ vào tin nhắn CUỐI CÙNG (dùng khi đang stream phản
  // hồi AI dần dần) — sửa TRỰC TIẾP trên object ChatMessage cuối thay vì
  // tạo tin nhắn mới mỗi lần, để không bị "nháy" danh sách liên tục.
  void appendToLastMessage(String delta) {
    if (messages.isEmpty) return;
    final last = messages.last;
    last.text += delta;
    last.isTyping = false;
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