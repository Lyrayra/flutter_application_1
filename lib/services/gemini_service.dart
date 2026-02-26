import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;

  bool get isConfigured => _model != null;

  void configure(String apiKey, {String model = 'gemini-1.5-flash'}) {
    if (apiKey.isEmpty) {
      _model = null;
      _chat = null;
      return;
    }
    _model = GenerativeModel(
      model: model,
      apiKey: apiKey,
      systemInstruction: Content.text(
        'あなたはLinuxサーバーの管理を手伝うアシスタントです。'
        'ユーザーの質問に日本語で答えてください。'
        'コマンドを実行する必要がある場合は、必ず「コマンドを実行します: <コマンド>」という形式で返してください。'
        '一度に複数のコマンドを実行したい場合は、この形式を複数行書いてください。',
      ),
    );
    _chat = _model!.startChat();
  }

  void resetChat() {
    if (_model != null) {
      _chat = _model!.startChat();
    }
  }

  Future<String> sendMessage(String message) async {
    if (_chat == null) {
      throw Exception('Gemini APIキーが設定されていません');
    }
    final response = await _chat!.sendMessage(Content.text(message));
    return response.text ?? '(応答なし)';
  }

  /// AIの応答からすべての実行コマンドを抽出する
  static List<String> extractCommands(String response) {
    final regex = RegExp(r'コマンドを実行します:\s*(.+)');
    final matches = regex.allMatches(response);
    return matches
        .map((m) => m.group(1)?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
  }
}
