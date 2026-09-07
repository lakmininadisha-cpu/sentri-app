import 'dart:convert';
import 'package:http/http.dart' as http;

// A thin wrapper around the Gemini API's generateContent endpoint,
// giving Sentri access to genuine large-language-model reasoning
// rather than the rule-based heuristics used elsewhere in the app
// (Section 5.3/5.6 of the report). Used for two features: natural
// language understanding in the voice assistant, and short
// AI-generated insights on the Weekly Summary screen.
class GeminiService {
  static const String _apiKey = 'GEMINI_API_KEY';
  static const String _model = 'gemini-3.5-flash';

  Future<String?> generateText(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          // Keep responses short — this is a mobile UI, not a chat
          // window, so a rambling multi-paragraph reply would be a
          // poor fit regardless of how good the model is. Gemini 3.x
          // models default to an internal "thinking" step before
          // answering, which can eat into a small token budget and
          // cut the real answer short — thinkingLevel: minimal keeps
          // that overhead low for this simple, single-turn use case,
          // and the token budget is set generously to leave room for
          // both the (small) thinking step and the actual answer.
          'generationConfig': {
            'maxOutputTokens': 500,
            'thinkingConfig': {
              'thinkingLevel': 'minimal',
            },
          },
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      return (parts[0]['text'] as String?)?.trim();
    } catch (e) {
      return null;
    }
  }
}