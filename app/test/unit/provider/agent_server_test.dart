import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/quick_save_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/provider/agent_server_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

void main() {
  group('setting', () {
    late MockPersistenceService persistence;

    setUp(() {
      provideDummy<ThemeMode>(ThemeMode.system);
      provideDummy<ColorMode>(ColorMode.system);
      provideDummy<Color>(Colors.blue);
      provideDummy<QuickSaveMode>(QuickSaveMode.off);
      provideDummy<SendMode>(SendMode.single);

      persistence = MockPersistenceService();
      when(persistence.getAgentServer()).thenReturn(true);
    });

    test('Should read the persisted value', () {
      final container = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(persistence)]);

      expect(container.read(settingsProvider).agentServer, true);
    });

    test('Should update the settings state and persist it', () async {
      final container = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(persistence)]);

      await container.notifier(settingsProvider).setAgentServer(false);

      expect(container.read(settingsProvider).agentServer, false);
      verify(persistence.setAgentServer(false));
    });
  });

  group('agentServerArgs', () {
    test('Should serve MCP over loopback HTTP and end with the app', () {
      final args = agentServerArgs();

      expect(args, containsAllInOrder(['--alias', 'Claude', '--port', '$agentServerDevicePort', 'mcp', '--http', '127.0.0.1:$agentServerPort']));
      expect(args.last, '--exit-on-stdin-close');
      expect(args, isNot(contains('--destination')));
    });

    test('Should save to the destination of the app', () {
      final args = agentServerArgs(destination: '/tmp/in');

      expect(args, containsAllInOrder(['--destination', '/tmp/in', 'mcp']));
    });

    test('Should not collide with the port of the app', () {
      expect(agentServerDevicePort, isNot(53317));
    });
  });

  group('findAgentServerBinary', () {
    final name = Platform.isWindows ? 'localsend-cli.exe' : 'localsend-cli';
    final s = Platform.pathSeparator;
    final appDir = '${Directory.systemTemp.path}${s}ls_app';
    final executable = '$appDir${s}localsend_app';

    test('Should prefer the CLI installed next to the app', () {
      final installed = '$appDir${s}cli$s$name';

      final found = findAgentServerBinary(executable: executable, exists: (path) => path == installed);

      expect(found, installed);
    });

    test('Should find the CLI built in a parent repository', () {
      final built = '${Directory(appDir).parent.path}${s}target${s}debug$s$name';

      final found = findAgentServerBinary(executable: executable, exists: (path) => path == built);

      expect(found, built);
    });

    test('Should return null without a CLI', () {
      expect(findAgentServerBinary(executable: executable, exists: (_) => false), isNull);
    });
  });
}
