import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import '../services/gemini_service.dart';
import '../services/ssh_settings.dart';
import '../screens/settings_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.isSystem = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatPanel extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const ChatPanel({super.key, this.onSettingsChanged});

  @override
  State<ChatPanel> createState() => ChatPanelState();
}

class ChatPanelState extends State<ChatPanel> {
  final GeminiService _gemini = GeminiService();
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;
  SshSettings _settings = SshSettings();

  // SSH関連
  SSHClient? _sshClient;
  SSHSession? _sshSession;
  bool _sshConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SshSettings.load();
    setState(() => _settings = settings);
    if (_settings.geminiApiKey.isNotEmpty) {
      _gemini.configure(_settings.geminiApiKey, model: _settings.geminiModel);
    }
    await _connectSsh();
  }

  Future<void> _connectSsh() async {
    try {
      await _disconnectSsh();
      final socket = await SSHSocket.connect(_settings.host, _settings.port);

      if (_settings.authType == 'key') {
        final keyFile = await _readKeyFile(_settings.keyPath);
        if (keyFile == null) return;
        _sshClient = SSHClient(
          socket,
          username: _settings.username,
          identities: SSHKeyPair.fromPem(keyFile),
        );
      } else {
        _sshClient = SSHClient(
          socket,
          username: _settings.username,
          onPasswordRequest: () => _settings.password,
        );
      }

      _sshSession = await _sshClient!.shell(
        pty: SSHPtyConfig(width: 80, height: 25, type: 'xterm-256color'),
      );
      setState(() => _sshConnected = true);
      _sshClient!.done.then((_) {
        if (mounted) setState(() => _sshConnected = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _sshConnected = false);
      }
    }
  }

  Future<String?> _readKeyFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _disconnectSsh() async {
    try {
      _sshSession?.close();
    } catch (_) {}
    try {
      _sshClient?.close();
    } catch (_) {}
    _sshSession = null;
    _sshClient = null;
    _sshConnected = false;
  }

  Future<String> _executeSshCommand(String command) async {
    if (!_sshConnected || _sshClient == null) {
      return '[SSH未接続] コマンドを実行できませんでした';
    }
    try {
      // 設定されたLinuxパスに移動してからコマンドを実行
      final path = _settings.linuxPath;
      final fullCommand = 'cd $path && $command';
      final result = await _sshClient!.run(fullCommand);
      return utf8.decode(result, allowMalformed: true);
    } catch (e) {
      return '[SSHエラー] $e';
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final response = await _gemini.sendMessage(text);
      await _processAiResponse(response);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: '❌ エラー: $e', isSystem: true));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  /// AIからの応答を処理し、必要に応じてコマンドを実行する
  Future<void> _processAiResponse(String response) async {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: response));
    });
    _scrollToBottom();

    // コマンド自動実行
    final commands = GeminiService.extractCommands(response);
    if (commands.isEmpty) return;

    // --- コマンド実行のユーザー確認 ---
    if (!mounted) return;
    final commandText = commands.join('\n');
    final bool? shouldExecute = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('コマンドの実行確認'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AIが以下のコマンドを実行しようとしています。許可しますか？'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    commandText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'キャンセル',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('実行する'),
            ),
          ],
        );
      },
    );

    if (shouldExecute != true) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: '🚫 ユーザーによってコマンドの実行がキャンセルされました',
              isSystem: true,
            ),
          );
        });
        _scrollToBottom();
      }

      final feedback = await _gemini.sendMessage(
        'ユーザーがセキュリティ上の理由でコマンドの実行をキャンセルしました。別の方法を提案するか、実行しなかったことを認識してください。',
      );
      // 再帰的に処理を継続
      await _processAiResponse(feedback);
      return;
    }

    final List<String> results = [];
    for (final command in commands) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(text: '⚙️ コマンド実行中: $command', isSystem: true),
          );
        });
        _scrollToBottom();
      }

      final output = await _executeSshCommand(command);
      results.add('[$command] の結果:\n$output');

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: '📋 実行結果:\n$output', isSystem: true));
        });
        _scrollToBottom();
      }
    }

    // 全ての結果をまとめてAIにフィードバック
    final feedback = await _gemini.sendMessage(
      '以下のコマンドを実行しました:\n${results.join('\n\n')}',
    );
    // フィードバックに対するAIの応答を再帰的に処理
    await _processAiResponse(feedback);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (result == true) {
      widget.onSettingsChanged?.call();
      await _loadSettings();
    }
  }

  void _clearChat() {
    setState(() => _messages.clear());
    _gemini.resetChat();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _disconnectSsh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: ClipRect(child: _buildChatArea())),
        if (_gemini.isConfigured) _buildInputArea(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF263238),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Gemini チャット',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          // SSH接続ステータス
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _sshConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _sshConnected ? 'SSH接続済' : 'SSH未接続',
            style: TextStyle(
              color: _sshConnected ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'チャットクリア',
            onPressed: _clearChat,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: '設定',
            onPressed: _openSettings,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (!_gemini.isConfigured) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Gemini APIキーが設定されていません',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('設定画面を開く'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Geminiに質問してみましょう',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          msg.text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.35,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SelectableText(
          msg.text,
          style: TextStyle(
            fontSize: 13.5,
            color: isUser ? Colors.white : Colors.black87,
            height: 1.4,
            fontFamily: 'Noto Sans JP',
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              decoration: InputDecoration(
                hintText: 'メッセージを入力...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isSending ? Colors.grey : const Color(0xFF4CAF50),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isSending ? null : _sendMessage,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
