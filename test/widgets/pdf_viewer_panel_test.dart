import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/widgets/pdf_viewer_panel.dart';

class MockFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic onFileLoading,
    bool? allowCompression,
    int? compressionQuality = 30,
    bool? allowMultiple,
    bool? withData,
    bool? withReadStream,
    bool? lockParentWindow,
    bool? readSequential,
  }) async {
    throw Exception('Simulated error');
  }
}

void main() {
  testWidgets('PdfViewerPanel shows error SnackBar when file picker fails', (WidgetTester tester) async {
    // Setup Mock
    FilePicker.platform = MockFilePicker();

    // Pump Widget
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PdfViewerPanel(),
      ),
    ));

    // Find and Tap Button
    final folderButton = find.widgetWithIcon(IconButton, Icons.folder_open);
    expect(folderButton, findsOneWidget);

    await tester.tap(folderButton);
    await tester.pump(); // Trigger frame

    // Wait for SnackBar animation
    await tester.pump(const Duration(seconds: 1));

    // Verify SnackBar
    expect(find.text('ファイル選択エラー: Exception: Simulated error'), findsOneWidget);
  });
}
