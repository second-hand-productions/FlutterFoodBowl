import 'package:pocketbase/pocketbase.dart';

enum LidState { unknown, open, closed }

class Bowl {
  final String pbId;
  final String id;
  String name;
  LidState lidState;

  Bowl({
    required this.pbId,
    required this.id,
    required this.name,
    this.lidState = LidState.unknown,
  });

  factory Bowl.fromRecord(RecordModel record) => Bowl(
        pbId: record.id,
        id: record.getStringValue('bowl_id'),
        name: record.getStringValue('name'),
      );
}
