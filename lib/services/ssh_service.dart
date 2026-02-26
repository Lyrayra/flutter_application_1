import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// A service to abstract SSH operations and file system access for better testability.
class SshService {
  const SshService();

  /// Connects to an SSH server.
  Future<SSHSocket> connect(String host, int port) {
    return SSHSocket.connect(host, port);
  }

  /// Creates an SSH client using the provided socket and authentication details.
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

  /// Parses an SSH key from a PEM string.
  List<SSHKeyPair> parseKey(String content) {
    return SSHKeyPair.fromPem(content);
  }

  /// Checks if a key file exists at the given path.
  Future<bool> keyFileExists(String path) {
    return File(path).exists();
  }

  /// Reads the content of a key file.
  Future<String> readKeyFile(String path) {
    return File(path).readAsString();
  }
}
