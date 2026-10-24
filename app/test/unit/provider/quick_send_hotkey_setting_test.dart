import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/quick_save_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

void main() {
  late MockPersistenceService persistence;

  setUp(() {
    provideDummy<ThemeMode>(ThemeMode.system);
    provideDummy<ColorMode>(ColorMode.system);
    provideDummy<Color>(Colors.blue);
    provideDummy<QuickSaveMode>(QuickSaveMode.off);
    provideDummy<SendMode>(SendMode.single);

    persistence = MockPersistenceService();
    when(persistence.getQuickSendHotkey()).thenReturn(false);
  });

  test('Should be disabled by default', () {
    final container = RefenaContainer(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
    );

    expect(container.read(settingsProvider).quickSendHotkey, false);
  });

  test('Should update the settings state and persist it', () async {
    final container = RefenaContainer(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
    );

    await container.notifier(settingsProvider).setQuickSendHotkey(true);

    expect(container.read(settingsProvider).quickSendHotkey, true);
    verify(persistence.setQuickSendHotkey(true));

    await container.notifier(settingsProvider).setQuickSendHotkey(false);

    expect(container.read(settingsProvider).quickSendHotkey, false);
    verify(persistence.setQuickSendHotkey(false));
  });
}
