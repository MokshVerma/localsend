import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/tray_helper.dart';
import 'package:localsend_app/widget/dialogs/quick_send_dialog.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:win32/win32.dart' as win32;
import 'package:window_manager/window_manager.dart';

final _logger = Logger('QuickSend');

// Ctrl+Win+C is taken by the Windows color filter shortcut.
final _hotKey = HotKey(
  key: PhysicalKeyboardKey.keyC,
  modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
);

bool _busy = false;

/// Registers or unregisters the global hotkey that sends the current selection
/// (or the clipboard) to a device picked from a list. Only supported on Windows and macOS.
Future<void> setQuickSendHotkeyEnabled(bool enabled) async {
  try {
    if (enabled) {
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => unawaited(_handleHotKey()));
    } else {
      await hotKeyManager.unregister(_hotKey);
    }
  } catch (e) {
    _logger.warning('Failed to ${enabled ? 'register' : 'unregister'} the quick send hotkey', e);
  }
}

Future<void> _handleHotKey() async {
  if (_busy) {
    return;
  }
  _busy = true;
  try {
    final ref = RefenaScope.defaultRef;

    // macOS only sends what is already on the clipboard:
    // simulating the key press needs the Accessibility permission, which sandboxed apps cannot get.
    if (checkPlatform([TargetPlatform.windows])) {
      _simulateCopy();
      // Give the foreground app time to fill the clipboard.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
    if (!await pickClipboardIntoSelection(ref)) {
      return;
    }

    final wasVisible = await windowManager.isVisible();
    await showFromTray();

    final device = await showDialog<Device>(
      // ignore: use_build_context_synchronously
      context: Routerino.context,
      builder: (_) => const QuickSendDialog(),
    );
    if (device == null) {
      if (!wasVisible) {
        await hideToTray();
      }
      return;
    }

    await ref
        .notifier(sendProvider)
        .startSession(
          target: device,
          files: ref.read(selectedSendingFilesProvider),
          background: false,
        );
  } catch (e, stackTrace) {
    _logger.warning('Quick send failed', e, stackTrace);
  } finally {
    _busy = false;
  }
}

/// Presses Ctrl+C in the foreground app.
/// The user still holds the hotkey modifiers, so Alt is released first.
void _simulateCopy() {
  const steps = [
    (win32.VK_MENU, true),
    (win32.VK_C, true),
    (win32.VK_CONTROL, false),
    (win32.VK_C, false),
    (win32.VK_C, true),
    (win32.VK_CONTROL, true),
  ];

  final inputs = calloc<win32.INPUT>(steps.length);
  try {
    for (var i = 0; i < steps.length; i++) {
      final (key, up) = steps[i];
      inputs[i].type = win32.INPUT_KEYBOARD;
      inputs[i].Anonymous.ki.wVk = key;
      inputs[i].Anonymous.ki.dwFlags = up ? win32.KEYEVENTF_KEYUP : 0;
    }
    win32.SendInput(steps.length, inputs, sizeOf<win32.INPUT>());
  } finally {
    calloc.free(inputs);
  }
}
