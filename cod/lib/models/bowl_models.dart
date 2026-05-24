import 'package:pocketbase/pocketbase.dart';

enum BrokerState { disconnected, connecting, connected, error }

class FoodBowlConfig {
  const FoodBowlConfig({this.recordId, required this.id, required this.name});

  factory FoodBowlConfig.fromRecord(RecordModel record) {
    final bowlId = record.data['bowl_id'];
    final name = record.data['name'];
    final id = bowlId is String ? bowlId.trim() : '';

    return FoodBowlConfig(
      recordId: record.id,
      id: id,
      name: name is String && name.trim().isNotEmpty ? name.trim() : id,
    );
  }

  final String? recordId;
  final String id;
  final String name;

  FoodBowlConfig copyWith({String? recordId, String? id, String? name}) {
    return FoodBowlConfig(
      recordId: recordId ?? this.recordId,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class BowlRuntimeState {
  const BowlRuntimeState({
    this.status = 'No status received yet',
    this.availability = 'unknown',
    this.lastCommand = 'None',
    this.lastResult = 'No result received yet',
  });

  final String status;
  final String availability;
  final String lastCommand;
  final String lastResult;

  BowlRuntimeState copyWith({
    String? status,
    String? availability,
    String? lastCommand,
    String? lastResult,
  }) {
    return BowlRuntimeState(
      status: status ?? this.status,
      availability: availability ?? this.availability,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class BowlDiscovery {
  const BowlDiscovery({required this.bowlId, this.macAddress, this.ipAddress});

  final String bowlId;
  final String? macAddress;
  final String? ipAddress;
}
