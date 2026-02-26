import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SshSettings {
  static const _keyHost = 'ssh_host';
  static const _keyPort = 'ssh_port';
  static const _keyUsername = 'ssh_username';
  static const _keyAuthType = 'ssh_auth_type'; // 'key' or 'password'
  static const _keyKeyPath = 'ssh_key_path';
  static const _keyPassword = 'ssh_password';
  static const _keyLinuxPath = 'linux_path';
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyGeminiModel = 'gemini_model';
  static const _keyRightPanelMode = 'right_panel_mode'; // 'chat' or 'terminal'

  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 8022;
  static const String defaultUsername = 'u0_a345';
  static const String defaultKeyPath = '/storage/emulated/0/Download/id_rsa';
  static const String defaultLinuxPath = '~/storage/Termux';
  static const String defaultGeminiModel = 'gemini-1.5-flash';

  static List<String> availableModels = [defaultGeminiModel];

  static Future<void> fetchModels(String apiKey) async {
    if (apiKey.isEmpty) return;
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['models'] != null) {
          final List<String> models = [];
          for (var model in data['models']) {
            if (model['supportedGenerationMethods']?.contains(
                  'generateContent',
                ) ==
                true) {
              final name = model['name'] as String;
              models.add(name.replaceAll('models/', ''));
            }
          }
          if (models.isNotEmpty) {
            availableModels = models;
          }
        }
      }
    } catch (_) {}
  }

  String host;
  int port;
  String username;
  String authType; // 'key' or 'password'
  String keyPath;
  String password;
  String linuxPath;
  String geminiApiKey;
  String geminiModel;
  String rightPanelMode; // 'chat' or 'terminal'

  SshSettings({
    this.host = defaultHost,
    this.port = defaultPort,
    this.username = defaultUsername,
    this.authType = 'key',
    this.keyPath = defaultKeyPath,
    this.password = '',
    this.linuxPath = defaultLinuxPath,
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
    this.rightPanelMode = 'chat',
  });

  static Future<SshSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SshSettings(
      host: prefs.getString(_keyHost) ?? defaultHost,
      port: prefs.getInt(_keyPort) ?? defaultPort,
      username: prefs.getString(_keyUsername) ?? defaultUsername,
      authType: prefs.getString(_keyAuthType) ?? 'key',
      keyPath: prefs.getString(_keyKeyPath) ?? defaultKeyPath,
      password: prefs.getString(_keyPassword) ?? '',
      linuxPath: prefs.getString(_keyLinuxPath) ?? defaultLinuxPath,
      geminiApiKey: prefs.getString(_keyGeminiApiKey) ?? '',
      geminiModel: prefs.getString(_keyGeminiModel) ?? defaultGeminiModel,
      rightPanelMode: prefs.getString(_keyRightPanelMode) ?? 'chat',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setInt(_keyPort, port);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyAuthType, authType);
    await prefs.setString(_keyKeyPath, keyPath);
    await prefs.setString(_keyPassword, password);
    await prefs.setString(_keyLinuxPath, linuxPath);
    await prefs.setString(_keyGeminiApiKey, geminiApiKey);
    await prefs.setString(_keyGeminiModel, geminiModel);
    await prefs.setString(_keyRightPanelMode, rightPanelMode);
  }
}
