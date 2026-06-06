import 'package:pocketbase/pocketbase.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/models/bowl_models.dart';

abstract class BowlRepository {
  Future<List<FoodBowlConfig>> loadBowls();
  Future<FoodBowlConfig?> findBowl(String bowlId);
  Future<FoodBowlConfig> createBowl(FoodBowlConfig bowl);
  Future<void> deleteBowl(FoodBowlConfig bowl);
  Future<FoodBowlConfig?> renameBowl(FoodBowlConfig bowl, String name);
}

class PocketBaseBowlRepository implements BowlRepository {
  PocketBaseBowlRepository({PocketBase? pocketBase})
    : _pb = pocketBase ?? PocketBase(pocketBaseUri);

  final PocketBase _pb;

  @override
  Future<List<FoodBowlConfig>> loadBowls() async {
    final records = await _pb
        .collection(bowlsCollection)
        .getFullList(sort: 'name');
    return records.map(FoodBowlConfig.fromRecord).toList();
  }

  @override
  Future<FoodBowlConfig?> findBowl(String bowlId) async {
    final result = await _pb
        .collection(bowlsCollection)
        .getList(page: 1, perPage: 1, filter: 'bowl_id = "$bowlId"');
    return result.items.isEmpty
        ? null
        : FoodBowlConfig.fromRecord(result.items.first);
  }

  @override
  Future<FoodBowlConfig> createBowl(FoodBowlConfig bowl) async {
    final record = await _pb
        .collection(bowlsCollection)
        .create(body: {'bowl_id': bowl.id, 'name': bowl.name}, files: []);
    return FoodBowlConfig.fromRecord(record);
  }

  @override
  Future<void> deleteBowl(FoodBowlConfig bowl) async {
    final recordId = bowl.recordId ?? (await findBowl(bowl.id))?.recordId;
    if (recordId == null) {
      return;
    }

    await _pb.collection(bowlsCollection).delete(recordId);
  }

  @override
  Future<FoodBowlConfig?> renameBowl(FoodBowlConfig bowl, String name) async {
    final recordId = bowl.recordId ?? (await findBowl(bowl.id))?.recordId;
    if (recordId == null) {
      return null;
    }

    final record = await _pb
        .collection(bowlsCollection)
        .update(recordId, body: {'name': name});
    return FoodBowlConfig.fromRecord(record);
  }
}
