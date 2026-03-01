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
      expect(settings.username, SshSettings.defaultUsername);
      expect(settings.authType, 'key');
      expect(settings.keyPath, SshSettings.defaultKeyPath);
      expect(settings.password, '');
      expect(settings.linuxPath, SshSettings.defaultLinuxPath);
    });

    test('load returns default values when explicit nulls are retrieved via remove()', () async {
      SharedPreferences.setMockInitialValues({
        'ssh_host': 'temp',
        'ssh_port': 1234,
        'ssh_username': 'temp',
        'ssh_auth_type': 'temp',
        'ssh_key_path': 'temp',
        'ssh_password': 'temp',
        'linux_path': 'temp',
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ssh_host');
      await prefs.remove('ssh_port');
      await prefs.remove('ssh_username');
      await prefs.remove('ssh_auth_type');
      await prefs.remove('ssh_key_path');
      await prefs.remove('ssh_password');
      await prefs.remove('linux_path');

      expect(prefs.getString('ssh_host'), isNull);
      expect(prefs.getInt('ssh_port'), isNull);

      final settings = await SshSettings.load();
      expect(settings.host, SshSettings.defaultHost);
      expect(settings.port, SshSettings.defaultPort);
      expect(settings.username, SshSettings.defaultUsername);
      expect(settings.authType, 'key');
      expect(settings.keyPath, SshSettings.defaultKeyPath);
      expect(settings.password, '');
      expect(settings.linuxPath, SshSettings.defaultLinuxPath);
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
      expect(settings.password, '');
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

      // Mutating fields after instantiation to verify all properties are saved correctly
      settings.username = 'directcheck_user';
      settings.authType = 'password';
      settings.keyPath = '/directcheck/key';
      settings.password = 'directcheck_pass';
      settings.linuxPath = '/directcheck/linux';

      await settings.save();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ssh_host'), 'directcheck.com');
      expect(prefs.getInt('ssh_port'), 1234);
      expect(prefs.getString('ssh_username'), 'directcheck_user');
      expect(prefs.getString('ssh_auth_type'), 'password');
      expect(prefs.getString('ssh_key_path'), '/directcheck/key');
      expect(prefs.getString('ssh_password'), 'directcheck_pass');
      expect(prefs.getString('linux_path'), '/directcheck/linux');
    });
  });
}
