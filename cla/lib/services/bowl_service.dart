import '../config.dart';
import '../models/bowl.dart';

class BowlService {
  Future<List<Bowl>> loadBowls() async {
    final records = await pb.collection('bowls').getFullList(sort: 'created');
    return records.map(Bowl.fromRecord).toList();
  }

  void subscribe({
    required void Function(Bowl bowl) onCreate,
    required void Function(String pbId) onDelete,
    required void Function(String pbId, String name) onUpdate,
  }) {
    pb.collection('bowls').subscribe('*', (e) {
      if (e.record == null) return;
      if (e.action == 'create') {
        onCreate(Bowl.fromRecord(e.record!));
      } else if (e.action == 'delete') {
        onDelete(e.record!.id);
      } else if (e.action == 'update') {
        onUpdate(e.record!.id, e.record!.getStringValue('name'));
      }
    });
  }

  Future<Bowl> addBowl(String id, String name) async {
    final record = await pb
        .collection('bowls')
        .create(body: {'bowl_id': id, 'name': name});
    return Bowl.fromRecord(record);
  }

  Future<void> removeBowl(String pbId) =>
      pb.collection('bowls').delete(pbId);

  Future<void> renameBowl(String pbId, String newName) =>
      pb.collection('bowls').update(pbId, body: {'name': newName});

  void unsubscribe() => pb.collection('bowls').unsubscribe();
}
