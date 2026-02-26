import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ssh_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _keyPathCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _linuxPathCtrl;
  late TextEditingController _geminiApiKeyCtrl;
  String _authType = 'key';
  String _geminiModel = SshSettings.defaultGeminiModel;
  String _rightPanelMode = 'chat';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController();
    _portCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _keyPathCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _linuxPathCtrl = TextEditingController();
    _geminiApiKeyCtrl = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SshSettings.load();
    setState(() {
      _hostCtrl.text = settings.host;
      _portCtrl.text = settings.port.toString();
      _usernameCtrl.text = settings.username;
      _authType = settings.authType;
      _keyPathCtrl.text = settings.keyPath;
      _passwordCtrl.text = settings.password;
      _linuxPathCtrl.text = settings.linuxPath;
      _geminiApiKeyCtrl.text = settings.geminiApiKey;
      _geminiModel = settings.geminiModel;
      if (!SshSettings.availableModels.contains(_geminiModel)) {
        _geminiModel = SshSettings.defaultGeminiModel;
      }
      _rightPanelMode = settings.rightPanelMode;
      _isLoading = false;
    });
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _keyPathCtrl.text = result.files.single.path!;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = SshSettings(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim(),
      authType: _authType,
      keyPath: _keyPathCtrl.text.trim(),
      password: _passwordCtrl.text,
      linuxPath: _linuxPathCtrl.text.trim(),
      geminiApiKey: _geminiApiKeyCtrl.text.trim(),
      geminiModel: _geminiModel,
      rightPanelMode: _rightPanelMode,
    );
    await settings.save();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定を保存しました')));
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _keyPathCtrl.dispose();
    _passwordCtrl.dispose();
    _linuxPathCtrl.dispose();
    _geminiApiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 一般設定 ---
                    _sectionTitle('一般設定'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _linuxPathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Linuxパス',
                        hintText: '~/storage/Termux',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '右側パネル表示',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'chat',
                          label: Text('チャット'),
                          icon: Icon(Icons.chat),
                        ),
                        ButtonSegment(
                          value: 'terminal',
                          label: Text('ターミナル'),
                          icon: Icon(Icons.terminal),
                        ),
                      ],
                      selected: {_rightPanelMode},
                      onSelectionChanged: (s) =>
                          setState(() => _rightPanelMode = s.first),
                    ),
                    const SizedBox(height: 24),

                    // --- AI設定 ---
                    _sectionTitle('AI設定 (Gemini)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _geminiApiKeyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Gemini APIキー',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _geminiModel,
                            decoration: const InputDecoration(
                              labelText: 'Gemini モデル (一覧取得にはAPIキーが必要)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.memory),
                            ),
                            items: SshSettings.availableModels.map((model) {
                              return DropdownMenuItem(
                                value: model,
                                child: Text(model),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _geminiModel = newValue;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'モデル一覧を取得',
                          onPressed: () async {
                            final key = _geminiApiKeyCtrl.text.trim();
                            if (key.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('先にAPIキーを入力してください'),
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('モデル一覧を取得中...')),
                            );
                            await SshSettings.fetchModels(key);
                            if (mounted) {
                              setState(() {
                                if (!SshSettings.availableModels.contains(
                                  _geminiModel,
                                )) {
                                  _geminiModel =
                                      SshSettings.availableModels.first;
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('モデル一覧を更新しました')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- SSH接続設定 ---
                    _sectionTitle('SSH接続設定'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IPアドレス',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'IPアドレスを入力してください'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ポート番号',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 65535) {
                          return '有効なポート番号を入力してください (1-65535)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ユーザー名',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'ユーザー名を入力してください'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('認証方法'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'key',
                          label: Text('秘密鍵ファイル'),
                          icon: Icon(Icons.key),
                        ),
                        ButtonSegment(
                          value: 'password',
                          label: Text('パスワード'),
                          icon: Icon(Icons.lock),
                        ),
                      ],
                      selected: {_authType},
                      onSelectionChanged: (s) =>
                          setState(() => _authType = s.first),
                    ),
                    const SizedBox(height: 12),
                    if (_authType == 'key') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _keyPathCtrl,
                              decoration: const InputDecoration(
                                labelText: '秘密鍵ファイルのパス',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.insert_drive_file),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '秘密鍵ファイルのパスを指定してください'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickKeyFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('選択'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'パスワード',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'パスワードを入力してください' : null,
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('保存して閉じる'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF263238),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.1,
      ),
    );
  }
}
