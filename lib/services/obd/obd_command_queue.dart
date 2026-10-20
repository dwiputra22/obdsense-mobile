import 'dart:async';
import 'i_obd_transport.dart';

class ObdQueuedCommand {
  final String command;
  final Completer<String> completer;
  final Duration timeout;

  ObdQueuedCommand({
    required this.command,
    required this.completer,
    required this.timeout,
  });
}

class ObdCommandQueue {
  final IObdTransport transport;
  final List<ObdQueuedCommand> _queue = <ObdQueuedCommand>[];
  bool _processing = false;
  bool _disposed = false;
  StreamSubscription<String>? _sub;
  StringBuffer _buffer = StringBuffer();

  DateTime lastReplyAt = DateTime.now();

  ObdCommandQueue(this.transport);

  Future<String> send(
      String command, {
        Duration timeout = const Duration(milliseconds: 1200),
      }) {
    if (_disposed) return Future.error(StateError('OBD command queue sudah ditutup.'));
    final completer = Completer<String>();
    _queue.add(
      ObdQueuedCommand(
        command: command,
        completer: completer,
        timeout: timeout,
      ),
    );
    unawaited(_process());
    return completer.future;
  }

  Future<void> _process() async {
    if (_processing || _disposed || _queue.isEmpty) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final item = _queue.removeAt(0);
        _buffer = StringBuffer();
        final responseCompleter = item.completer;
        await _sub?.cancel();
        _sub = transport.responses.listen((chunk) {
          _buffer.write(chunk);
          final current = _buffer.toString();
          if (current.contains('>') && !responseCompleter.isCompleted) {
            lastReplyAt = DateTime.now();
            responseCompleter.complete(current);
          }
        });

        Timer? timer;
        try {
          timer = Timer(item.timeout, () {
            if (!responseCompleter.isCompleted) {
              responseCompleter.completeError(TimeoutException('Timeout command OBD: ${item.command}'));
            }
          });
          await transport.send(item.command);
          await responseCompleter.future;
        } catch (error, stack) {
          if (!responseCompleter.isCompleted) responseCompleter.completeError(error, stack);
          // Keep queue alive; the caller handles individual command failures.
          try { await responseCompleter.future; } catch (_) {}
        } finally {
          timer?.cancel();
          await _sub?.cancel();
          _sub = null;
        }
      }
    } finally {
      _processing = false;
      if (_queue.isNotEmpty && !_disposed) unawaited(_process());
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    for (final item in _queue) {
      if (!item.completer.isCompleted) item.completer.completeError(StateError('OBD command queue ditutup.'));
    }
    _queue.clear();
  }
}