import 'dart:async';

enum DataSyncKind { glucosePoint, glucoseBulk, eventItem, eventBulk }

class DataSyncEvent {
  DataSyncEvent(this.kind, this.payload);
  final DataSyncKind kind;
  final Map<String, dynamic> payload; // e.g., {'time': DateTime, 'value': double}
}

class DataSyncBus {
  DataSyncBus._internal();
  static final DataSyncBus _instance = DataSyncBus._internal();
  factory DataSyncBus() => _instance;

  final StreamController<DataSyncEvent> _controller = StreamController<DataSyncEvent>.broadcast();
  Stream<DataSyncEvent> get stream => _controller.stream;

  void emitGlucosePoint({required DateTime time, required double value}) {
    _controller.add(DataSyncEvent(DataSyncKind.glucosePoint, {
      'time': time,
      'value': value,
    }));
  }

  void emitGlucoseBulk({int? count}) {
    _controller.add(DataSyncEvent(DataSyncKind.glucoseBulk, {
      if (count != null) 'count': count,
    }));
  }

  void emitEventItem(Map<String, dynamic> event) {
    _controller.add(DataSyncEvent(DataSyncKind.eventItem, event));
  }

  void emitEventBulk({int? count}) {
    _controller.add(DataSyncEvent(DataSyncKind.eventBulk, {
      if (count != null) 'count': count,
    }));
  }
}


