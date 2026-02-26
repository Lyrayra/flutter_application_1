import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';
import '../services/ssh_settings.dart';
import '../screens/settings_screen.dart';

class SshTerminalPanel extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const SshTerminalPanel({super.key, this.onSettingsChanged});

  @override
  State<SshTerminalPanel> createState() => _SshTerminalPanelState();
}

class _SshTerminalPanelState extends State<SshTerminalPanel> {
  late Terminal _terminal;
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;
  bool _isConnecting = false;
  SshSettings _settings = SshSettings();

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _loadSettingsAndConnect();
  }

  Future<void> _loadSettingsAndConnect() async {
    final settings = await SshSettings.load();
    setState(() => _settings = settings);
    await _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    _terminal.write(
      'Connecting to ${_settings.host}:${_settings.port} ...\r\n',
    );

    try {
      final socket = await SSHSocket.connect(_settings.host, _settings.port);

      if (_settings.authType == 'key') {
        // 秘密鍵認証
        final keyFile = File(_settings.keyPath);
        if (!await keyFile.exists()) {
          _terminal.write(
            '\x1B[31m[Error] 秘密鍵ファイルが見つかりません: ${_settings.keyPath}\x1B[0m\r\n',
          );
          setState(() => _isConnecting = false);
          socket.destroy();
          return;
        }
        final keyContent = await keyFile.readAsString();
        _client = SSHClient(
          socket,
          username: _settings.username,
          identities: SSHKeyPair.fromPem(keyContent),
        );
      } else {
        // パスワード認証
        _client = SSHClient(
          socket,
          username: _settings.username,
          onPasswordRequest: () => _settings.password,
        );
      }

      // シェルの起動
      _session = await _client!.shell(
        pty: SSHPtyConfig(width: 80, height: 25, type: 'xterm-256color'),
      );

      _terminal.write('\x1B[32mConnected!\x1B[0m\r\n');
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

      // SSH stdout → ターミナル表示
      _session!.stdout.listen(
        (data) {
          _terminal.write(utf8.decode(data, allowMalformed: true));
        },
        onDone: _onDisconnected,
        onError: (error) {
          _terminal.write('\r\n\x1B[31m[Error] $error\x1B[0m\r\n');
          _onDisconnected();
        },
      );

      // SSH stderr → ターミナル表示
      _session!.stderr.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      // ターミナル入力 → SSH stdin
      _terminal.onOutput = (data) {
        _session?.write(Uint8List.fromList(utf8.encode(data)));
      };

      // ターミナルリサイズ → SSH PTYリサイズ
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _session?.resizeTerminal(width, height);
      };

      // 接続切断の検知
      _client!.done.then((_) => _onDisconnected());
    } catch (e) {
      _terminal.write('\r\n\x1B[31m[Connection Error] $e\x1B[0m\r\n');
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    }
  }

  void _onDisconnected() {
    if (!_isConnected) return;
    _terminal.write('\r\n\x1B[33m[SSH接続が切断されました]\x1B[0m\r\n');
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      _session?.close();
    } catch (_) {}
    try {
      _client?.close();
    } catch (_) {}
    _session = null;
    _client = null;
    if (mounted) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _reconnect() async {
    await _disconnect();
    _terminal.write('\r\n--- 再接続中 ---\r\n');
    final settings = await SshSettings.load();
    setState(() => _settings = settings);
    await _connect();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (result == true) {
      widget.onSettingsChanged?.call();
      // 設定が保存されたので再接続
      await _reconnect();
    }
  }

  @override
  void dispose() {
    try {
      _session?.close();
    } catch (_) {}
    try {
      _client?.close();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: TerminalView(
            _terminal,
            textStyle: const TerminalStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              fontFamilyFallback: ['Noto Sans JP'],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF263238),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            'SSH (${_settings.host}:${_settings.port})',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          // 接続ステータスインジケーター
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnecting
                  ? Colors.orange
                  : _isConnected
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _isConnecting
                ? '接続中...'
                : _isConnected
                ? '接続済み'
                : '切断',
            style: TextStyle(
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'SSH設定',
            onPressed: _isConnecting ? null : _openSettings,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '再接続',
            onPressed: _isConnecting ? null : _reconnect,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
