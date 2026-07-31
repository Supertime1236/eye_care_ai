import 'package:dio/dio.dart';
import '../config/env.dart';

/// OpenRouter AI Service
///
/// API Key lấy từ:
/// flutter run --dart-define=OPENROUTER_API_KEY=sk-or-v1-xxxxx
///
/// hoặc GitHub Actions.
///
/// Không hardcode API key vào source code.
class EyeChatService {
  EyeChatService._();

  static final EyeChatService instance = EyeChatService._();

  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Bạn có thể đổi model tại đây
  static const String _model = 'deepseek/deepseek-chat-v3.1:free';
  // Ví dụ:
  // google/gemma-3-27b-it:free
  // meta-llama/llama-3.3-70b-instruct:free
  // mistralai/mistral-small-3.2-24b-instruct:free

  static const String _systemPrompt = '''
Bạn là trợ lý AI của ứng dụng EyeCare AI.

Bạn CHỈ được trả lời các câu hỏi liên quan đến:

- sức khỏe mắt
- thị lực
- cận thị
- viễn thị
- loạn thị
- mỏi mắt
- quy tắc 20-20-20
- ánh sáng khi học/làm việc
- thời gian dùng màn hình
- dinh dưỡng cho mắt
- bài tập thư giãn mắt
- giấc ngủ ảnh hưởng đến mắt
- phòng tránh bệnh về mắt

Nếu người dùng hỏi về chủ đề khác như:

- lập trình
- toán
- game
- phim
- tin tức
- tâm sự
- chính trị
- tài chính

thì hãy lịch sự từ chối và nói rằng bạn chỉ hỗ trợ về sức khỏe mắt.

Không chẩn đoán bệnh.

Nếu triệu chứng nghiêm trọng hoặc kéo dài hãy khuyên người dùng đến bác sĩ chuyên khoa mắt.

Trả lời ngắn gọn, dễ hiểu, thân thiện.
''';

  Future<String> sendMessage({
    required List<Map<String, String>> history,
  }) async {
    final apiKey = Env.openRouterApiKey;

    if (apiKey.isEmpty) {
      throw Exception("missing_api_key");
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    try {
      final messages = <Map<String, dynamic>>[
        {
          "role": "system",
          "content": _systemPrompt,
        },
      ];

      for (final item in history) {
        messages.add({
          "role": item["role"] == "assistant"
              ? "assistant"
              : "user",
          "content": item["content"] ?? "",
        });
      }

      final response = await dio.post(
        _baseUrl,
        options: Options(
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",

            // Thay bằng repo hoặc website của bạn
            "HTTP-Referer":
                "https://github.com/Supertime1236/eye_care_ai",

            "X-Title": "EyeCare AI",
          },
        ),
        data: {
          "model": _model,
          "messages": messages,
        },
      );

      final choices = response.data["choices"];

      if (choices == null || choices.isEmpty) {
        throw Exception("empty_response");
      }

      final content = choices[0]["message"]["content"];

      if (content == null) {
        throw Exception("empty_response");
      }

      if (content is String) {
        return content.trim();
      }

      // Một số model trả về dạng List
      if (content is List) {
        return content
            .map((e) => e["text"] ?? "")
            .join("\n")
            .trim();
      }

      return content.toString();
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      switch (status) {
        case 401:
        case 403:
          throw Exception("invalid_api_key");

        case 429:
          throw Exception("rate_limited");

        case 400:
          throw Exception("bad_request");

        case 500:
        case 502:
        case 503:
          throw Exception("server_error");
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception("network_error");
      }

      throw Exception("server_error");
    }
  }
}