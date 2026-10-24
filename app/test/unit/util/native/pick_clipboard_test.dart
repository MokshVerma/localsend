import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pasteboardChannel = MethodChannel('pasteboard');

  late RefenaContainer container;
  String? clipboardText;
  List<String> pasteboardFiles = [];

  setUp(() {
    container = RefenaContainer();
    clipboardText = null;
    pasteboardFiles = [];

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboardText == null ? null : {'text': clipboardText};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(pasteboardChannel, (call) async {
      if (call.method == 'files') {
        return pasteboardFiles;
      }
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(pasteboardChannel, null);
  });

  test('Should return false and select nothing if the clipboard is empty', () async {
    final added = await pickClipboardIntoSelection(container);

    expect(added, false);
    expect(container.read(selectedSendingFilesProvider), isEmpty);
  });

  test('Should select clipboard text as a message', () async {
    clipboardText = 'hello';

    final added = await pickClipboardIntoSelection(container);

    expect(added, true);
    final selected = container.read(selectedSendingFilesProvider);
    expect(selected, hasLength(1));
    expect(selected.first.bytes, 'hello'.codeUnits);
  });

  test('Should prefer text over files', () async {
    clipboardText = 'hello';
    pasteboardFiles = ['ignored.txt'];

    await pickClipboardIntoSelection(container);

    final selected = container.read(selectedSendingFilesProvider);
    expect(selected, hasLength(1));
    expect(selected.first.bytes, 'hello'.codeUnits);
  });
}
