import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/ssh_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SshSettings Tests', () {
    test('save() persists all settings correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SshSettings(
        host: 'example.com',
        port: 2222,
        username: 'test_user',
        authType: 'password',
        keyPath: '/path/to/key',
        password: 'secret_password',
        linuxPath: '/home/linux',
        geminiApiKey: 'api_key_123',
        geminiModel: 'gemini-pro',
        rightPanelMode: 'terminal',
      );

      await settings.save();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ssh_host'), 'example.com');
      expect(prefs.getInt('ssh_port'), 2222);
      expect(prefs.getString('ssh_username'), 'test_user');
      expect(prefs.getString('ssh_auth_type'), 'password');
      expect(prefs.getString('ssh_key_path'), '/path/to/key');
      expect(prefs.getString('ssh_password'), 'secret_password');
      expect(prefs.getString('linux_path'), '/home/linux');
      expect(prefs.getString('gemini_api_key'), 'api_key_123');
      expect(prefs.getString('gemini_model'), 'gemini-pro');
      expect(prefs.getString('right_panel_mode'), 'terminal');
    });

    test('save() persists default settings', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SshSettings(); // Use defaults

      await settings.save();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ssh_host'), SshSettings.defaultHost);
      expect(prefs.getInt('ssh_port'), SshSettings.defaultPort);
      expect(prefs.getString('ssh_username'), SshSettings.defaultUsername);
      expect(prefs.getString('ssh_auth_type'), 'key'); // Default authType
      expect(prefs.getString('ssh_key_path'), SshSettings.defaultKeyPath);
      expect(prefs.getString('ssh_password'), ''); // Default password
      expect(prefs.getString('linux_path'), SshSettings.defaultLinuxPath);
      expect(prefs.getString('gemini_api_key'), ''); // Default API key
      expect(prefs.getString('gemini_model'), SshSettings.defaultGeminiModel);
      expect(prefs.getString('right_panel_mode'), 'chat'); // Default mode
    });
  });
}
