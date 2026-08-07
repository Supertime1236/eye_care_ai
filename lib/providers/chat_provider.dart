import 'package:flutter/foundation.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.isAction = false,
  });

  String text;
  final bool isUser;
  bool isTyping;
  // true = đây là bong bóng xác nhận AI vừa thao tác thật với app (ví dụ
  // "Đã hạ mục tiêu dùng điện thoại xuống 4 giờ/ngày"), hiển thị khác màu
  // với bong bóng trả lời thông thường để người dùng dễ nhận ra.
  final bool isAction;
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

  // Ghi đè toàn bộ nội dung tin nhắn CUỐI CÙNG — dùng sau khi stream xong để
  // xoá khối %%ACTION%%...%%END%% (nếu có) khỏi văn bản hiển thị, mà không
  // cần tạo lại tin nhắn mới (giữ nguyên vị trí, tránh giật list).
  void setLastMessageText(String text) {
    if (messages.isEmpty) return;
    messages.last.text = text;
    notifyListeners();
  }

  void addActionMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: false, isAction: true));
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
        .where((m) => !m.isTyping && !m.isAction && m.text.trim().isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();
  }
}