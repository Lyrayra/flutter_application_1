import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import 'package:flutter_application_1/widgets/ssh_terminal_panel.dart';
import 'package:flutter_application_1/services/ssh_service.dart';

// Mocks
class MockSshService extends Mock implements SshService {}
class MockSSHSocket extends Mock implements SSHSocket {}
class MockSSHClient extends Mock implements SSHClient {}
class MockSSHSession extends Mock implements SSHSession {}

// Fakes
class FakeSSHKeyPair extends Fake implements SSHKeyPair {}
class FakeSSHSocket extends Fake implements SSHSocket {}

void main() {
  late MockSshService mockSshService;
  late MockSSHSocket mockSSHSocket;
  late MockSSHClient mockSSHClient;
  late MockSSHSession mockSSHSession;

  setUpAll(() {
    registerFallbackValue(SSHPtyConfig(width: 80, height: 25));
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeSSHSocket());
  });

  setUp(() {
    mockSshService = MockSshService();
    mockSSHSocket = MockSSHSocket();
    mockSSHClient = MockSSHClient();
    mockSSHSession = MockSSHSession();

    // Setup SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Default mocks behavior
    when(() => mockSSHSocket.destroy()).thenAnswer((_) {});
    when(() => mockSshService.connect(any(), any())).thenAnswer((_) async => mockSSHSocket);

    when(() => mockSshService.createClient(
      any(),
      username: any(named: 'username'),
      identities: any(named: 'identities'),
      onPasswordRequest: any(named: 'onPasswordRequest'),
    )).thenReturn(mockSSHClient);

    when(() => mockSSHClient.shell(pty: any(named: 'pty'))).thenAnswer((_) async => mockSSHSession);
    when(() => mockSSHClient.done).thenAnswer((_) => Completer<void>().future);
    when(() => mockSSHClient.close()).thenAnswer((_) async {});

    // Session streams - must not complete immediately for connection to stay open
    final stdoutController = StreamController<Uint8List>();
    final stderrController = StreamController<Uint8List>();
    addTearDown(() {
      stdoutController.close();
      stderrController.close();
    });

    when(() => mockSSHSession.stdout).thenAnswer((_) => stdoutController.stream);
    when(() => mockSSHSession.stderr).thenAnswer((_) => stderrController.stream);

    when(() => mockSSHSession.resizeTerminal(any(), any())).thenReturn(null);
    when(() => mockSSHSession.write(any())).thenReturn(null);
    when(() => mockSSHSession.close()).thenAnswer((_) async {});

    // Key parsing mock
    when(() => mockSshService.parseKey(any())).thenReturn([FakeSSHKeyPair()]);

    // File reading mock
    when(() => mockSshService.keyFileExists(any())).thenAnswer((_) async => true);
    when(() => mockSshService.readKeyFile(any())).thenAnswer((_) async => 'fake_key_content');
  });

  testWidgets('Initial connection state', (WidgetTester tester) async {
    // Delay connection to ensure we catch the 'Connecting...' state
    when(() => mockSshService.connect(any(), any())).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return mockSSHSocket;
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SshTerminalPanel(sshService: mockSshService),
      ),
    ));

    // Allow SshSettings.load to complete and _connect to start
    await tester.pump();

    // Should show connecting status
    expect(find.text('接続中...'), findsOneWidget);
    expect(find.byIcon(Icons.terminal), findsOneWidget);

    // Finish pending async work
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Successful connection with password', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'ssh_auth_type': 'password',
      'ssh_host': 'test.host',
      'ssh_port': 2222,
      'ssh_username': 'user',
      'ssh_password': 'password',
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SshTerminalPanel(sshService: mockSshService),
      ),
    ));

    // Trigger init
    await tester.pump();
    // Wait for async connection
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => mockSshService.connect('test.host', 2222)).called(1);
    verify(() => mockSshService.createClient(
      any(),
      username: 'user',
      onPasswordRequest: any(named: 'onPasswordRequest'),
    )).called(1);

    verify(() => mockSSHClient.shell(pty: any(named: 'pty'))).called(1);

    if (find.text('切断').evaluate().isNotEmpty) {
      fail('Widget is in Disconnected state. Expected Connected.');
    }
    if (find.text('接続中...').evaluate().isNotEmpty) {
      fail('Widget is stuck in Connecting state.');
    }

    expect(find.text('接続済み'), findsOneWidget);
  });

  testWidgets('Connection error displays error status', (WidgetTester tester) async {
     when(() => mockSshService.connect(any(), any())).thenThrow('Network error');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SshTerminalPanel(sshService: mockSshService),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('切断'), findsOneWidget);
  });

  testWidgets('Missing key file shows error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'ssh_auth_type': 'key',
      'ssh_key_path': '/path/to/key',
    });

    when(() => mockSshService.keyFileExists(any())).thenAnswer((_) async => false);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SshTerminalPanel(sshService: mockSshService),
      ),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => mockSshService.keyFileExists('/path/to/key')).called(1);

    expect(find.text('切断'), findsOneWidget);
  });
}
