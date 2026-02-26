import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/gemini_service.dart';

void main() {
  group('GeminiService.extractCommands', () {
    test('Extracts single command', () {
      const response = 'コマンドを実行します: ls -l';
      final commands = GeminiService.extractCommands(response);
      expect(commands, ['ls -l']);
    });

    test('Extracts multiple commands', () {
      const response = 'コマンドを実行します: ls\nコマンドを実行します: pwd';
      final commands = GeminiService.extractCommands(response);
      expect(commands, ['ls', 'pwd']);
    });

    test('Extracts command with full-width colon', () {
      const response = 'コマンドを実行します： whoami';
      final commands = GeminiService.extractCommands(response);
      expect(commands, ['whoami']);
    });

    test('Extracts commands mixed with text', () {
      const response = 'はい。ではまずディレクトリを確認します。\nコマンドを実行します: ls\n次にパスを表示します。\nコマンドを実行します: pwd';
      final commands = GeminiService.extractCommands(response);
      expect(commands, ['ls', 'pwd']);
    });

    test('Handles multiple commands in a row without extra text', () {
      const response = 'コマンドを実行します: cd /tmp\nコマンドを実行します: touch test.txt';
      final commands = GeminiService.extractCommands(response);
      expect(commands, ['cd /tmp', 'touch test.txt']);
    });
  });
}
