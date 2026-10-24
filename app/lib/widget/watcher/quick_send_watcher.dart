import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/native/quick_send_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Keeps the global quick send hotkey in sync with the setting.
class QuickSendWatcher extends StatefulWidget {
  final Widget child;

  const QuickSendWatcher({required this.child});

  @override
  State<QuickSendWatcher> createState() => _QuickSendWatcherState();
}

class _QuickSendWatcherState extends State<QuickSendWatcher> with Refena {
  bool _registered = false;

  @override
  void dispose() {
    if (_registered) {
      unawaited(setQuickSendHotkeyEnabled(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        checkPlatform([TargetPlatform.windows, TargetPlatform.macOS]) && ref.watch(settingsProvider.select((settings) => settings.quickSendHotkey));
    if (enabled != _registered) {
      _registered = enabled;
      unawaited(setQuickSendHotkeyEnabled(enabled));
    }
    return widget.child;
  }
}
