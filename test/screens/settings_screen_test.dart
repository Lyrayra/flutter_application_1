import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';

// Mock FilePicker to bypass platform channel and initialization issues
class MockFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic onFileLoading,
    bool allowCompression = true,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    int compressionQuality = 30,
  }) async {
    return FilePickerResult([
      PlatformFile(
        path: '/mocked/selected/key.pem',
        name: 'key.pem',
        size: 1024,
      ),
    ]);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ssh_host': '192.168.1.100',
      'ssh_port': 2222,
      'ssh_username': 'testuser',
      'ssh_auth_type': 'key',
      'ssh_key_path': '/path/to/key',
      'ssh_password': 'password123',
      'linux_path': '/data/user/0/com.termux/files/home',
      'gemini_api_key': 'test_api_key',
      'gemini_model': 'gemini-1.5-flash',
      'right_panel_mode': 'terminal',
    });

    // Inject MockFilePicker
    FilePicker.platform = MockFilePicker();
  });

  testWidgets('SettingsScreen loads initial values', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('192.168.1.100'), findsOneWidget);
    expect(find.text('2222'), findsOneWidget);
    expect(find.text('testuser'), findsOneWidget);
    expect(find.text('/path/to/key'), findsOneWidget);

    // Check that password field is NOT visible (only key path)
    expect(find.widgetWithText(TextFormField, 'パスワード'), findsNothing);
  });

  testWidgets('SettingsScreen saves values', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Enter new values
    await tester.enterText(find.widgetWithText(TextFormField, 'IPアドレス'), '10.0.0.1');
    await tester.enterText(find.widgetWithText(TextFormField, 'ポート番号'), '8022');
    await tester.enterText(find.widgetWithText(TextFormField, 'ユーザー名'), 'newuser');

    // Tap Save
    final saveButton = find.text('保存して閉じる');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ssh_host'), '10.0.0.1');
    expect(prefs.getInt('ssh_port'), 8022);
    expect(prefs.getString('ssh_username'), 'newuser');
  });

  testWidgets('SettingsScreen validates inputs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Clear required fields
    await tester.enterText(find.widgetWithText(TextFormField, 'IPアドレス'), '');
    await tester.enterText(find.widgetWithText(TextFormField, 'ユーザー名'), '');

    // Tap Save
    final saveButton = find.text('保存して閉じる');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Check for error messages
    expect(find.text('IPアドレスを入力してください'), findsOneWidget);
    expect(find.text('ユーザー名を入力してください'), findsOneWidget);

    // Verify saving did not happen
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ssh_host'), '192.168.1.100');
  });

  testWidgets('SettingsScreen toggles auth type', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Initially 'key' is selected
    expect(find.widgetWithText(TextFormField, '秘密鍵ファイルのパス'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'パスワード'), findsNothing);

    // Switch to 'password'
    // Tap the 'パスワード' text which is part of the SegmentedButton
    await tester.tap(find.text('パスワード'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '秘密鍵ファイルのパス'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'パスワード'), findsOneWidget); // Now visible field

    // Enter password
    await tester.enterText(find.widgetWithText(TextFormField, 'パスワード'), 'newpass');

    // Save
    final saveButton = find.text('保存して閉じる');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ssh_auth_type'), 'password');
    expect(prefs.getString('ssh_password'), 'newpass');
  });

  testWidgets('SettingsScreen file picker interaction', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    // Tap file picker button
    final pickerButton = find.text('選択');
    await tester.ensureVisible(pickerButton);
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();

    // Verify path is updated
    expect(find.text('/mocked/selected/key.pem'), findsOneWidget);
  });
}
