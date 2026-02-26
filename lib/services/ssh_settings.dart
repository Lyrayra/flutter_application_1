import 'package:shared_preferences/shared_preferences.dart';

class SshSettings {
  static const _keyHost = 'ssh_host';
  static const _keyPort = 'ssh_port';
  static const _keyUsername = 'ssh_username';
  static const _keyAuthType = 'ssh_auth_type'; // 'key' or 'password'
  static const _keyKeyPath = 'ssh_key_path';
  static const _keyPassword = 'ssh_password';

  static const String defaultHost = '127.0.0.1';
  static const int defaultPort = 8022;
  static const String defaultUsername = 'u0_a345';
  static const String defaultKeyPath = '/storage/emulated/0/Download/id_rsa';

  String host;
  int port;
  String username;
  String authType; // 'key' or 'password'
  String keyPath;
  String password;

  SshSettings({
    this.host = defaultHost,
    this.port = defaultPort,
    this.username = defaultUsername,
    this.authType = 'key',
    this.keyPath = defaultKeyPath,
    this.password = '',
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
  }
}
