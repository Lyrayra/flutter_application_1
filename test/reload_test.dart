import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/widgets/pdf_viewer_panel.dart';

class MockFilePicker extends FilePicker {
  String? path;
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
    if (path == null) return null;
    return FilePickerResult([
      PlatformFile(path: path!, name: path!.split('/').last, size: 10),
    ]);
  }
}

void main() {
  testWidgets('PdfViewerPanel reloads changed text file content', (WidgetTester tester) async {
    final tempFile = File('test_reload.txt');
    await tempFile.writeAsString('Original Content');

    final mockPicker = MockFilePicker();
    mockPicker.path = tempFile.absolute.path;
    FilePicker.platform = mockPicker;

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PdfViewerPanel(),
      ),
    ));

    // Open file
    await tester.tap(find.widgetWithIcon(IconButton, Icons.folder_open));
    await tester.pumpAndSettle();

    expect(find.text('Original Content'), findsOneWidget);

    // Modify file
    await tempFile.writeAsString('Updated Content');

    // Reload
    await tester.tap(find.widgetWithIcon(IconButton, Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Updated Content'), findsOneWidget);

    // Cleanup
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });
}
