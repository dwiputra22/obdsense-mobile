import 'dart:async';

abstract class IObdTransport {
  Stream<String> get responses;
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> send(String command);
}