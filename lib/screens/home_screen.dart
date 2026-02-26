import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/pdf_viewer_panel.dart';
import '../widgets/ssh_terminal_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted) {
      if (mounted) {
        _showPermissionSnackBar();
      }
    }
  }

  void _showPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ストレージへのアクセス権限が必要です。設定画面から許可してください。'),
        action: SnackBarAction(
          label: '設定を開く',
          onPressed: () => openAppSettings(),
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Row(
          children: [
            const Expanded(child: PdfViewerPanel()),
            Container(width: 1, color: Colors.grey[400]),
            const Expanded(child: SshTerminalPanel()),
          ],
        ),
      ),
    );
  }
}
