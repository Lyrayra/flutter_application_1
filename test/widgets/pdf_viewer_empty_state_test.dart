import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/widgets/pdf_viewer_panel.dart';

class MockFilePicker extends FilePicker {
  bool pickFilesCalled = false;

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
    pickFilesCalled = true;
    return null;
  }
}

void main() {
  testWidgets('PdfViewerPanel empty state is actionable', (WidgetTester tester) async {
    // Setup Mock
    final mockFilePicker = MockFilePicker();
    FilePicker.platform = mockFilePicker;

    // Pump Widget
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PdfViewerPanel(),
      ),
    ));

    // Verify initial empty state text
    expect(find.text('PDFやテキストファイルを表示できます'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);

    // Find and tap the new action button.
    // The previous finder failed, possibly because of how ElevatedButton.icon structures its children.
    // Instead, we'll find the text widget itself and then tap it.
    final openButtonText = find.text('ファイルを開く');
    expect(openButtonText, findsOneWidget);

    await tester.tap(openButtonText);
    await tester.pump();

    // Verify pickFiles was called
    expect(mockFilePicker.pickFilesCalled, isTrue);
  });
}
