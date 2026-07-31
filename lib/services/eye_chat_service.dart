import 'package:dio/dio.dart';
import '../config/env.dart';

/// Gọi OpenRouter API để chat AI, giới hạn nghiêm ngặt trong chủ đề sức khoẻ
/// mắt bằng system prompt. API key lấy từ biến môi trường lúc build
/// (--dart-define=OPENROUTER_API_KEY=...), không lưu trong SharedPreferences.
class EyeChatService {
  EyeChatService._();
  static final EyeChatService instance = EyeChatService._();

  static const _model = 'google/gemma-3-27b-it:free';
  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const _systemPrompt = '''
Bạn là trợ lý AI của ứng dụng EyeCare AI. Bạn CHỈ được trả lời các câu hỏi
liên quan đến: sức khoẻ mắt, thị lực, thói quen dùng màn hình, quy tắc
20-20-20, ánh sáng phòng, giấc ngủ ảnh hưởng tới mắt, dinh dưỡng cho mắt, và
các bài tập/mẹo bảo vệ mắt.

Nếu người dùng hỏi về chủ đề KHÔNG liên quan tới mắt (bài tập về nhà, lập
trình, tin tức, tâm sự cá nhân không liên quan, v.v.), hãy lịch sự từ chối và
nhắc rằng bạn chỉ hỗ trợ các câu hỏi về sức khoẻ mắt, rồi gợi ý quay lại chủ
đề đó.

Trả lời ngắn gọn, dễ hiểu, giọng thân thiện, phù hợp với người dùng phổ thông
kể cả thanh thiếu niên. KHÔNG đưa ra chẩn đoán y khoa chắc chắn — nếu triệu
chứng nghiêm trọng hoặc kéo dài, luôn khuyên người dùng đi khám bác sĩ nhãn
khoa.
''';

  /// Gửi lịch sử hội thoại tới OpenRouter, trả về câu trả lời dạng text.
  /// `history` là danh sách {role: 'user'|'assistant', content: '...'} theo
  /// đúng thứ tự hội thoại.
  /// Ném Exception với mã lỗi ngắn gọn để UI tự dịch sang thông báo phù hợp:
  /// invalid_api_key | rate_limited | network_error | server_error
  Future<String> sendMessage({
    final String apiKey = Env.openRouterApiKey,
    required List<Map<String, String>> history,
  }) async {
    final dio = Dio();
    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...history.map(
          (m) => {
            'role': m['role'] == 'assistant' ? 'assistant' : 'user',
            'content': m['content'] ?? '',
          },
        ),
      ];

      final response = await dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://eyecare-ai.app',
            'X-Title': 'EyeCare AI',
          },
        ),
        data: {
          'model': _model,
          'messages': messages,
        },
      );

      final choices = response.data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('empty_response');
      }
      final text =
          (choices.first['message']?['content'] as String?)?.trim();
      if (text == null || text.isEmpty) {
        throw Exception('empty_response');
      }
      return text;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        throw Exception('invalid_api_key');
      } else if (status == 429) {
        throw Exception('rate_limited');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('network_error');
      }
      throw Exception('server_error');
    }
  }
}
