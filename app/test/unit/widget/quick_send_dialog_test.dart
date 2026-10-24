import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/widget/dialogs/quick_send_dialog.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../../mocks.mocks.dart';

class _FakeIsolateController extends Fake implements IsolateController {}

void main() {
  Future<void> pumpDialog(WidgetTester tester, Map<String, Device> devices, {required ValueChanged<Device?> onResult}) async {
    final container = RefenaContainer(
      overrides: [
        nearbyDevicesProvider.overrideWithInitialState(
          notifier: (ref) => NearbyDevicesService(
            isolateController: _FakeIsolateController(),
            favoriteService: FavoritesService(MockPersistenceService()),
            discoveryLogs: DiscoveryLogger(),
          ),
          initialState: NearbyDevicesState(runningFavoriteScan: false, runningIps: {}, devices: devices, signalingDevices: {}),
        ),
      ],
    );

    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await showDialog<Device>(context: context, builder: (_) => const QuickSendDialog())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Should show a hint if there are no devices', (tester) async {
    await pumpDialog(tester, {}, onResult: (_) {});

    expect(find.text(t.dialogs.quickSendDialog.noDevices), findsOneWidget);
  });

  testWidgets('Should list devices and return the tapped one', (tester) async {
    Device? result;
    final phone = _createDevice('abc', alias: 'My Phone');
    final laptop = _createDevice('def', alias: 'My Laptop');
    await pumpDialog(tester, {phone.fingerprint: phone, laptop.fingerprint: laptop}, onResult: (d) => result = d);

    expect(find.text('My Phone'), findsOneWidget);
    expect(find.text('My Laptop'), findsOneWidget);

    await tester.tap(find.text('My Phone'));
    await tester.pumpAndSettle();

    expect(result, phone);
    expect(find.byType(QuickSendDialog), findsNothing);
  });

  testWidgets('Should return null when cancelled', (tester) async {
    var called = false;
    Device? result = _createDevice('x');
    await pumpDialog(
      tester,
      {'abc': _createDevice('abc')},
      onResult: (d) {
        called = true;
        result = d;
      },
    );

    await tester.tap(find.text(t.general.cancel));
    await tester.pumpAndSettle();

    expect(called, true);
    expect(result, isNull);
  });
}

Device _createDevice(String fingerprint, {String alias = 'Device'}) {
  return Device(
    signalingId: null,
    ip: '1.2.3.4',
    version: '2.1',
    port: 53317,
    https: true,
    fingerprint: fingerprint,
    alias: alias,
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    channels: const [],
  );
}
