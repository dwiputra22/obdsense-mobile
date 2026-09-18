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
  final List<ObdQueuedCommand> _queue = [];
  bool _processing = false;
  StreamSubscription<String>? _sub;

  final StringBuffer _buffer = StringBuffer();

  ObdCommandQueue(this.transport);

  Future<String> send(
      String command, {
        Duration timeout = const Duration(seconds: 3),
      }) {
    final completer = Completer<String>();
    _queue.add(
      ObdQueuedCommand(
        command: command,
        completer: completer,
        timeout: timeout,
      ),
    );
    _process();
    return completer.future;
  }

  Future<void> _process() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;

    final item = _queue.removeAt(0);
    _buffer.clear();

    await transport.send(item.command);

    _sub?.cancel();
    _sub = transport.responses.listen((chunk) {
      _buffer.write(chunk);
      if (_buffer.toString().contains('>')) {
        final result = _buffer.toString();
        if (!item.completer.isCompleted) {
          item.completer.complete(result);
        }
      }
    });

    Future.delayed(item.timeout, () {
      if (!item.completer.isCompleted) {
        item.completer.completeError(
          TimeoutException('Timeout command OBD: ${item.command}'),
        );
      }
    });

    try {
      await item.completer.future;
    } catch (_) {}

    await _sub?.cancel();
    _processing = false;
    _process();
  }

  void dispose() {
    _sub?.cancel();
  }
}