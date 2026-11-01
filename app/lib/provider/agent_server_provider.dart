import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('AgentServer');

/// The loopback port of the MCP endpoint that AI agents connect to.
const agentServerPort = 53319;

/// The LocalSend port of the agent's own device. The app itself keeps the default one.
const agentServerDevicePort = 53318;

/// The URL to register in an MCP client.
const agentServerUrl = 'http://127.0.0.1:$agentServerPort/mcp';

enum AgentServerStatus {
  stopped,
  starting,
  running,
  failed,

  /// The CLI that implements the server was not found.
  unavailable,
}

@immutable
class AgentServerState {
  final AgentServerStatus status;
  final String? error;

  const AgentServerState(this.status, {this.error});
}

/// Runs `localsend-cli mcp --http` as a child process next to the app.
///
/// The child watches its stdin and ends with it, so it goes away together with the app, even when the app crashes.
final agentServerProvider = NotifierProvider<AgentServerService, AgentServerState>((ref) {
  return AgentServerService();
});

class AgentServerService extends Notifier<AgentServerState> {
  Process? _process;

  /// Bumped on every stop, so that the exit of a replaced process is not mistaken for a crash.
  int _generation = 0;

  @override
  AgentServerState init() => const AgentServerState(AgentServerStatus.stopped);

  Future<void> start() async {
    if (_process != null) {
      return;
    }
    final binary = findAgentServerBinary();
    if (binary == null) {
      state = const AgentServerState(AgentServerStatus.unavailable);
      return;
    }

    final generation = ++_generation;
    state = const AgentServerState(AgentServerStatus.starting);

    final Process process;
    try {
      process = await Process.start(binary, agentServerArgs(destination: ref.read(settingsProvider).destination));
    } catch (e) {
      _logger.warning('Could not start $binary', e);
      state = AgentServerState(AgentServerStatus.failed, error: e.toString());
      return;
    }
    if (generation != _generation) {
      // Stopped while spawning.
      process.kill();
      return;
    }
    _process = process;

    final lastLines = <String>[];
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      _logger.info(line);
      lastLines.add(line);
      if (lastLines.length > 5) {
        lastLines.removeAt(0);
      }
    });
    unawaited(process.stdout.drain<void>());
    unawaited(
      process.exitCode.then((code) {
        if (generation != _generation) {
          return;
        }
        _process = null;
        state = AgentServerState(
          AgentServerStatus.failed,
          error: lastLines.isNotEmpty ? lastLines.last : 'Exited with code $code',
        );
      }),
    );

    final ready = await _waitForPort(generation);
    if (generation == _generation && _process != null) {
      state = ready
          ? const AgentServerState(AgentServerStatus.running)
          : const AgentServerState(AgentServerStatus.failed, error: 'Did not start in time');
    }
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    _generation++;
    if (process != null) {
      // Closing stdin is the child's signal to shut down cleanly.
      try {
        await process.stdin.close();
      } catch (_) {}
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
    }
    if (state.status != AgentServerStatus.unavailable) {
      state = const AgentServerState(AgentServerStatus.stopped);
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<bool> _waitForPort(int generation) async {
    for (var i = 0; i < 50; i++) {
      if (generation != _generation || _process == null) {
        return false;
      }
      try {
        final socket = await Socket.connect('127.0.0.1', agentServerPort, timeout: const Duration(milliseconds: 200));
        socket.destroy();
        return true;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return false;
  }
}

/// The command line of the server: its own device is called "Claude" and saves to the app's destination.
@visibleForTesting
List<String> agentServerArgs({String? destination}) {
  return [
    '--alias',
    'Claude',
    '--port',
    '$agentServerDevicePort',
    if (destination != null) ...['--destination', destination],
    'mcp',
    '--http',
    '127.0.0.1:$agentServerPort',
    '--exit-on-stdin-close',
  ];
}

/// Finds `localsend-cli`: next to the app in an installation (`cli/`), or in the repository's `target/` during development.
@visibleForTesting
String? findAgentServerBinary({String? executable, bool Function(String path)? exists}) {
  final fileExists = exists ?? (path) => File(path).existsSync();
  final name = Platform.isWindows ? 'localsend-cli.exe' : 'localsend-cli';
  final separator = Platform.pathSeparator;

  var dir = File(executable ?? Platform.resolvedExecutable).parent;
  final installed = '${dir.path}${separator}cli$separator$name';
  if (fileExists(installed)) {
    return installed;
  }

  for (var i = 0; i < 8; i++) {
    for (final profile in ['release', 'debug']) {
      final candidate = '${dir.path}${separator}target$separator$profile$separator$name';
      if (fileExists(candidate)) {
        return candidate;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return null;
}
