import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/ssh_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(),
    ));
    await tester.pumpAndSettle(); // Wait for FutureBuilder/initState
  }

  Future<void> tapSave(WidgetTester tester) async {
    final saveButton = find.text('保存して閉じる');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  group('SettingsScreen Port Validation Tests', () {
    testWidgets('Valid port (8022) shows no error', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final portField = find.widgetWithText(TextFormField, 'ポート番号');
      expect(portField, findsOneWidget);

      await tester.enterText(portField, '8022');
      await tester.pump();

      await tapSave(tester);

      expect(find.text('有効なポート番号を入力してください (1-65535)'), findsNothing);
    });

    testWidgets('Invalid port (0) shows error', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final portField = find.widgetWithText(TextFormField, 'ポート番号');
      await tester.enterText(portField, '0');
      await tester.pump();

      await tapSave(tester);

      expect(find.text('有効なポート番号を入力してください (1-65535)'), findsOneWidget);
    });

    testWidgets('Invalid port (65536) shows error', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final portField = find.widgetWithText(TextFormField, 'ポート番号');
      await tester.enterText(portField, '65536');
      await tester.pump();

      await tapSave(tester);

      expect(find.text('有効なポート番号を入力してください (1-65535)'), findsOneWidget);
    });

    testWidgets('Non-numeric port shows error', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final portField = find.widgetWithText(TextFormField, 'ポート番号');
      await tester.enterText(portField, 'abc');
      await tester.pump();

      await tapSave(tester);

      expect(find.text('有効なポート番号を入力してください (1-65535)'), findsOneWidget);
    });

    testWidgets('Empty port shows error', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final portField = find.widgetWithText(TextFormField, 'ポート番号');
      await tester.enterText(portField, '');
      await tester.pump();

      await tapSave(tester);

      expect(find.text('有効なポート番号を入力してください (1-65535)'), findsOneWidget);
    });
  });
}
