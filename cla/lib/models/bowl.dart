import 'package:pocketbase/pocketbase.dart';
import 'camera.dart';

enum LidState { unknown, open, closed }

class Bowl {
  final String pbId;
  final String id;
  String name;
  LidState lidState;
  Camera? camera;

  Bowl({
    required this.pbId,
    required this.id,
    required this.name,
    this.lidState = LidState.unknown,
    this.camera,
  });

  factory Bowl.fromRecord(RecordModel record) {
    // Reads through the (optionally) expanded `camera` relation. Returns ''
    // when the bowl has no camera or the relation wasn't expanded.
    final frigateName = record.get<String>('expand.camera.frigate_name', '');
    return Bowl(
      pbId: record.id,
      id: record.getStringValue('bowl_id'),
      name: record.getStringValue('name'),
      camera: frigateName.isEmpty
          ? null
          : Camera(
              pbId: record.get<String>('expand.camera.id', ''),
              frigateName: frigateName,
            ),
    );
  }
}
