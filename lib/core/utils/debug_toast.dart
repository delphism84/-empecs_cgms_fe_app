import 'dart:async';

class DebugToastBus {
  DebugToastBus._internal();
  static final DebugToastBus _instance = DebugToastBus._internal();
  factory DebugToastBus() => _instance;

  final StreamController<String> _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void show(String message) {
    _controller.add(message);
  }
}


