import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/ssh_settings.dart';

void main() {
  group('SshSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SshSettings.availableModels = [SshSettings.defaultGeminiModel];
    });

    tearDown(() {
      SshSettings.availableModels = [SshSettings.defaultGeminiModel];
    });

    test('default constructor values', () {
      final settings = SshSettings();
      expect(settings.host, SshSettings.defaultHost);
      expect(settings.port, SshSettings.defaultPort);
      expect(settings.username, SshSettings.defaultUsername);
      expect(settings.authType, 'key');
      expect(settings.keyPath, SshSettings.defaultKeyPath);
      expect(settings.password, '');
      expect(settings.linuxPath, SshSettings.defaultLinuxPath);
      expect(settings.geminiApiKey, '');
      expect(settings.geminiModel, SshSettings.defaultGeminiModel);
      expect(settings.rightPanelMode, 'chat');
    });

    test('load returns default values when prefs are empty', () async {
      final settings = await SshSettings.load();
      expect(settings.host, SshSettings.defaultHost);
      expect(settings.port, SshSettings.defaultPort);
    });

    test('load returns saved values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'ssh_host': 'example.com',
        'ssh_port': 2222,
        'ssh_username': 'testuser',
        'ssh_auth_type': 'password',
        'ssh_key_path': '/path/to/key',
        'ssh_password': 'secretpassword',
        'linux_path': '/home/user',
        'gemini_api_key': 'api_key_123',
        'gemini_model': 'gemini-pro',
        'right_panel_mode': 'terminal',
      });

      final settings = await SshSettings.load();
      expect(settings.host, 'example.com');
      expect(settings.port, 2222);
      expect(settings.username, 'testuser');
      expect(settings.authType, 'password');
      expect(settings.keyPath, '/path/to/key');
      expect(settings.password, 'secretpassword');
      expect(settings.linuxPath, '/home/user');
      expect(settings.geminiApiKey, 'api_key_123');
      expect(settings.geminiModel, 'gemini-pro');
      expect(settings.rightPanelMode, 'terminal');
    });

    test('save writes values to SharedPreferences', () async {
      final settings = SshSettings(
        host: 'saved.com',
        port: 8080,
        username: 'saveduser',
        authType: 'password',
        keyPath: '/saved/key',
        password: 'savedpass',
        linuxPath: '/saved/linux',
        geminiApiKey: 'saved_key',
        geminiModel: 'saved-model',
        rightPanelMode: 'terminal',
      );

      await settings.save();

      final loadedSettings = await SshSettings.load();
      expect(loadedSettings.host, 'saved.com');
      expect(loadedSettings.port, 8080);
      expect(loadedSettings.username, 'saveduser');
      expect(loadedSettings.authType, 'password');
      expect(loadedSettings.keyPath, '/saved/key');
      expect(loadedSettings.password, 'savedpass');
      expect(loadedSettings.linuxPath, '/saved/linux');
      expect(loadedSettings.geminiApiKey, 'saved_key');
      expect(loadedSettings.geminiModel, 'saved-model');
      expect(loadedSettings.rightPanelMode, 'terminal');
    });

    test('fetchModels updates availableModels on success', () async {
      final client = MockClient((request) async {
        if (request.url.toString() ==
            'https://generativelanguage.googleapis.com/v1beta/models?key=test_api_key') {
          return http.Response(
            json.encode({
              'models': [
                {
                  'name': 'models/gemini-pro',
                  'supportedGenerationMethods': ['generateContent']
                },
                {
                  'name': 'models/gemini-1.5-flash',
                  'supportedGenerationMethods': ['generateContent']
                },
                {
                  'name': 'models/text-bison-001',
                  'supportedGenerationMethods': ['embedText'] // Not supported
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await http.runWithClient(() async {
        await SshSettings.fetchModels('test_api_key');
      }, () => client);

      expect(SshSettings.availableModels, ['gemini-pro', 'gemini-1.5-flash']);
    });

    test('fetchModels does not update availableModels on error', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final initialModels = List<String>.from(SshSettings.availableModels);

      await http.runWithClient(() async {
        await SshSettings.fetchModels('test_api_key');
      }, () => client);

      expect(SshSettings.availableModels, initialModels);
    });

    test('fetchModels does not update availableModels on empty api key', () async {
       final initialModels = List<String>.from(SshSettings.availableModels);
       await SshSettings.fetchModels('');
       expect(SshSettings.availableModels, initialModels);
    });
  });
}
