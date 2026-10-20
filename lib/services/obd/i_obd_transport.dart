import 'dart:async';

abstract class IObdTransport {
  Stream<String> get responses;
  bool get isConnected;

  Stream<bool> get connectionChanges;
  bool get supportsAutoReconnect;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> send(String command);
}