import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:file_picker/file_picker.dart';

class PdfViewerPanel extends StatefulWidget {
  const PdfViewerPanel({super.key});

  @override
  State<PdfViewerPanel> createState() => _PdfViewerPanelState();
}

class _PdfViewerPanelState extends State<PdfViewerPanel> {
  String? _filePath;
  String? _fileName;
  bool _isPdf = false;
  String? _textContent;
  int _reloadKey = 0;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _openFile(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイル選択エラー: $e')),
        );
      }
    }
  }

  Future<void> _openFile(String path) async {
    final name = path.split('/').last.split('\\').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    if (ext == 'pdf') {
      setState(() {
        _filePath = path;
        _fileName = name;
        _isPdf = true;
        _textContent = null;
        _reloadKey++;
      });
    } else {
      await _loadTextFile(path, name);
    }
  }

  Future<void> _loadTextFile(String path, [String? name]) async {
    try {
      final content = await File(path).readAsString();
      setState(() {
        _filePath = path;
        _fileName = name ?? _fileName;
        _isPdf = false;
        _textContent = content;
        _reloadKey++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  void _reloadFile() {
    if (_filePath == null) return;
    if (_isPdf) {
      setState(() => _reloadKey++);
    } else {
      _loadTextFile(_filePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'ファイルを開く',
            onPressed: _pickFile,
            iconSize: 22,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'リロード',
            onPressed: _filePath != null ? _reloadFile : null,
            iconSize: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fileName ?? 'ファイルを選択してください',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: _fileName != null ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_filePath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'PDFやテキストファイルを表示できます',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('ファイルを開く'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueGrey[900],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    if (_isPdf) {
      return PDFView(
        key: ValueKey('pdf_$_reloadKey'),
        filePath: _filePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: false,
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF読み込みエラー: $error')),
            );
          }
        },
        onPageError: (page, error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDFページエラー (p.$page): $error')),
            );
          }
        },
      );
    }

    // テキストファイル表示
    return Container(
      key: ValueKey('text_$_reloadKey'),
      color: const Color(0xFFFAFAFA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(
            _textContent ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
