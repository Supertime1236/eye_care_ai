import 'dart:convert';

import 'package:dio/dio.dart';
import '../config/env.dart';

/// NVIDIA NIM AI Service
///
/// API Key lấy từ:
/// flutter run --dart-define=NIM_API_KEY=nvapi-xxxxx
///
/// hoặc GitHub Actions.
///
/// Không hardcode API key vào source code.
/// Rate limits: 40 RPM, không giới hạn daily.
class EyeChatService {
  EyeChatService._();

  static final EyeChatService instance = EyeChatService._();

  static const String _baseUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  /// NVIDIA NIM: Google Gemma 4 31B it  — 40 RPM, trả lời nhanh.
  static const String _model = 'nvidia/nemotron-3-ultra-550b-a55b';

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

  // Bản STREAMING: thay vì chờ model trả lời XONG HẾT rồi mới hiện 1 lần
  // (sendMessage ở trên), hàm này trả về từng mẩu chữ ngay khi model sinh ra
  // (giống ChatGPT/Claude "gõ" dần trên màn hình). Tổng thời gian model xử
  // lý không đổi, nhưng CẢM GIÁC nhanh hơn RẤT NHIỀU vì người dùng thấy chữ
  // chạy ngay giây đầu tiên thay vì nhìn màn hình trắng/spinner cả chục
  // giây rồi mới hiện nguyên đoạn dài — đây là cách hầu hết chatbot AI làm
  // để "AI trả lời chậm" bớt khó chịu, kể cả khi dùng model free chậm.
  Stream<String> sendMessageStream({
    required List<Map<String, String>> history,
  }) async* {
    final apiKey = Env.nimApiKey;
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

    final messages = <Map<String, dynamic>>[
      {"role": "system", "content": _systemPrompt},
      for (final item in history)
        {
          "role": item["role"] == "assistant" ? "assistant" : "user",
          "content": item["content"] ?? "",
        },
    ];

    try {
      final response = await dio.post<ResponseBody>(
        _baseUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            "Authorization": "Bearer $apiKey",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
          },
        ),
        data: {
          "model": _model,
          "messages": messages,
          "stream": true,
        },
      );

      final stream = response.data!.stream;
      var buffer = '';
      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        // NVIDIA NIM gửi theo chuẩn SSE: mỗi sự kiện là 1 dòng bắt đầu bằng
        // "data: ", các sự kiện cách nhau bởi dòng trống. Model có thể trả
        // về nhiều dòng trong 1 lần đọc socket hoặc cắt giữa dòng -> phải
        // tách theo "\n" và giữ lại phần dòng cuối chưa hoàn chỉnh trong
        // buffer để nối tiếp ở lần đọc kế tiếp.
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          if (data.isEmpty) continue;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta is String && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {
            // Bỏ qua dòng JSON lỗi/không đầy đủ, không làm hỏng cả stream.
          }
        }
      }
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

  Future<String> sendMessage({
    required List<Map<String, String>> history,
  }) async {
    final apiKey = Env.nimApiKey;

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
