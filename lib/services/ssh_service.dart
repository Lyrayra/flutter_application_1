import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

class SshService {
  const SshService();

  Future<SSHSocket> connect(String host, int port) {
    return SSHSocket.connect(host, port);
  }

  SSHClient createClient(
    SSHSocket socket, {
    required String username,
    List<SSHKeyPair>? identities,
    String Function()? onPasswordRequest,
  }) {
    return SSHClient(
      socket,
      username: username,
      identities: identities,
      onPasswordRequest: onPasswordRequest,
    );
  }

  List<SSHKeyPair> parseKey(String content) {
    return SSHKeyPair.fromPem(content);
  }

  Future<bool> keyFileExists(String path) {
    return File(path).exists();
  }

  Future<String> readKeyFile(String path) {
    return File(path).readAsString();
  }
}
