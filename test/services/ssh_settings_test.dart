import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/ssh_settings.dart';

void main() {
  group('SshSettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
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
      });

      final settings = await SshSettings.load();
      expect(settings.host, 'example.com');
      expect(settings.port, 2222);
      expect(settings.username, 'testuser');
      expect(settings.authType, 'password');
      expect(settings.keyPath, '/path/to/key');
      expect(settings.password, 'secretpassword');
      expect(settings.linuxPath, '/home/user');
    });

    test('load merges partial saved values with defaults', () async {
      SharedPreferences.setMockInitialValues({
        'ssh_host': 'partial.com',
        'ssh_port': 9000,
      });

      final settings = await SshSettings.load();
      expect(settings.host, 'partial.com');
      expect(settings.port, 9000);
      // Verify missing values fall back to defaults
      expect(settings.username, SshSettings.defaultUsername);
      expect(settings.authType, 'key');
      expect(settings.keyPath, SshSettings.defaultKeyPath);
      expect(settings.linuxPath, SshSettings.defaultLinuxPath);
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
    });

    test('save persists values to underlying storage', () async {
      final settings = SshSettings(
        host: 'directcheck.com',
        port: 1234,
      );

      await settings.save();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ssh_host'), 'directcheck.com');
      expect(prefs.getInt('ssh_port'), 1234);
      expect(prefs.getString('ssh_username'), SshSettings.defaultUsername);
    });
  });
}
