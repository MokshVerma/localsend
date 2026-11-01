import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/provider/agent_server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Keeps the MCP server for AI agents in sync with its setting: it runs next to the app, and restarts when the
/// folder it saves to changes.
class AgentServerWatcher extends StatefulWidget {
  final Widget child;

  const AgentServerWatcher({required this.child});

  @override
  State<AgentServerWatcher> createState() => _AgentServerWatcherState();
}

class _AgentServerWatcherState extends State<AgentServerWatcher> with Refena {
  AgentServerService? _service;
  (bool, String?)? _applied;

  @override
  void dispose() {
    unawaited(_service?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = _service = ref.notifier(agentServerProvider);
    // One watch: Refena keeps a single selector per provider and widget.
    final (enabled, destination) = ref.watch(settingsProvider.select((settings) => (settings.agentServer, settings.destination)));
    final wanted = checkPlatformIsDesktop() && enabled;

    final next = (wanted, destination);
    if (next != _applied) {
      final first = _applied == null;
      _applied = next;
      unawaited(
        Future.microtask(() {
          if (!wanted) {
            return service.stop();
          }
          return first ? service.start() : service.restart();
        }),
      );
    }
    return widget.child;
  }
}
