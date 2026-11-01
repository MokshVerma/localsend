import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/quick_save_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/provider/agent_server_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/watcher/agent_server_watcher.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

class _RecordingAgentServer extends AgentServerService {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> restart() async => calls.add('restart');
}

void main() {
  late MockPersistenceService persistence;
  late _RecordingAgentServer server;
  late RefenaContainer container;

  setUp(() {
    provideDummy<ThemeMode>(ThemeMode.system);
    provideDummy<ColorMode>(ColorMode.system);
    provideDummy<Color>(Colors.blue);
    provideDummy<QuickSaveMode>(QuickSaveMode.off);
    provideDummy<SendMode>(SendMode.single);

    persistence = MockPersistenceService();
    when(persistence.getAgentServer()).thenReturn(true);
    server = _RecordingAgentServer();
    container = RefenaContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        agentServerProvider.overrideWithNotifier((ref) => server),
      ],
    );
  });

  Future<void> pumpWatcher(WidgetTester tester) {
    return tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: const MaterialApp(home: AgentServerWatcher(child: SizedBox())),
      ),
    );
  }

  testWidgets('Should start the server with the app when enabled', (tester) async {
    await pumpWatcher(tester);
    await tester.pump();

    expect(server.calls, ['start']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Should stop the server when the setting is switched off', (tester) async {
    await pumpWatcher(tester);
    await tester.pump();

    await container.notifier(settingsProvider).setAgentServer(false);
    await tester.pump();
    await tester.pump();

    expect(server.calls, ['start', 'stop']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Should start the server again when the setting is switched back on', (tester) async {
    await pumpWatcher(tester);
    await container.notifier(settingsProvider).setAgentServer(false);
    await tester.pump();
    await container.notifier(settingsProvider).setAgentServer(true);
    await tester.pump();
    await tester.pump();

    expect(server.calls, ['start', 'stop', 'restart']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Should not start the server when disabled', (tester) async {
    when(persistence.getAgentServer()).thenReturn(false);
    await pumpWatcher(tester);
    await tester.pump();

    expect(server.calls, ['stop']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
