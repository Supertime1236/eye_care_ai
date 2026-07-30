import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gọi Google Gemini API trực tiếp để chat AI THẬT, giới hạn nghiêm ngặt
/// trong chủ đề sức khoẻ mắt bằng system prompt.
///
/// ⚠️ QUAN TRỌNG VỀ BẢO MẬT: khoá API ở đây do NGƯỜI DÙNG tự nhập và chỉ lưu
/// cục bộ trên máy họ (SharedPreferences) — hệ số dùng cho MVP. TUYỆT ĐỐI
/// KHÔNG nhúng cứng khoá API riêng của bạn vào code rồi build APK, vì bất kỳ
/// ai giải nén APK cũng có thể lấy được khoá và dùng miễn phí bằng tiền của
/// bạn. Khi lên bản chính thức, nên làm một backend nhỏ (VD: Firebase Cloud
/// Function) giữ khoá API phía server, app chỉ gọi tới backend đó — service
/// này chỉ nên dùng để thử nghiệm/demo nội bộ.
///
/// Lấy khoá Gemini API MIỄN PHÍ tại: https://aistudio.google.com/apikey
/// Khoá hợp lệ luôn có dạng "AIzaSy..." — nếu khoá bạn có KHÔNG bắt đầu bằng
/// tiền tố này, đó không phải khoá Gemini API hợp lệ.
class EyeChatService {
  EyeChatService._();
  static final EyeChatService instance = EyeChatService._();

  static const _kApiKeyPref = 'pref_gemini_api_key';
  static const _model = 'gemini-2.0-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

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

  Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kApiKeyPref);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKeyPref, key.trim());
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kApiKeyPref);
  }

  /// Gửi lịch sử hội thoại tới Gemini API, trả về câu trả lời dạng text.
  /// `history` là danh sách {role: 'user'|'assistant', content: '...'} theo
  /// đúng thứ tự hội thoại — được chuyển sang định dạng `contents` của Gemini
  /// (role 'assistant' -> 'model') ngay trong hàm này.
  /// Ném Exception với mã lỗi ngắn gọn để UI tự dịch sang thông báo phù hợp.
  Future<String> sendMessage({
    required String apiKey,
    required List<Map<String, String>> history,
  }) async {
    final dio = Dio();
    try {
      final contents = history
          .map((m) => {
                'role': m['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': m['content'] ?? ''}
                ],
              })
          .toList();

      final response = await dio.post(
        '$_baseUrl/$_model:generateContent',
        queryParameters: {'key': apiKey},
        options: Options(headers: {'content-type': 'application/json'}),
        data: {
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt}
            ],
          },
          'contents': contents,
        },
      );

      final candidates = response.data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('empty_response');
      }
      final parts = candidates.first['content']?['parts'] as List<dynamic>?;
      final text = parts
          ?.map((p) => p['text'] as String? ?? '')
          .join('\n')
          .trim();
      if (text == null || text.isEmpty) {
        throw Exception('empty_response');
      }
      return text;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        throw Exception('invalid_api_key');
      } else if (status == 429) {
        throw Exception('rate_limited');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('network_error');
      }
      throw Exception('server_error');
    }
  }
}
