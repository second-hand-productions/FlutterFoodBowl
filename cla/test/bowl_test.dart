import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:food_bowl/models/bowl.dart';

void main() {
  group('Bowl.fromRecord', () {
    test('maps PocketBase fields and defaults lidState to unknown', () {
      final record = RecordModel({
        'id': 'pb_1',
        'bowl_id': 'a4cf123456ab',
        'name': 'Kitchen Bowl',
      });

      final bowl = Bowl.fromRecord(record);

      expect(bowl.pbId, 'pb_1');
      expect(bowl.id, 'a4cf123456ab');
      expect(bowl.name, 'Kitchen Bowl');
      expect(bowl.lidState, LidState.unknown);
      expect(bowl.camera, isNull);
    });

    test('parses an expanded camera relation when present', () {
      final record = RecordModel.fromJson({
        'id': 'pb_1',
        'bowl_id': 'a4cf123456ab',
        'name': 'Kitchen Bowl',
        'expand': {
          'camera': {'id': 'cam_1', 'frigate_name': 'zero1'},
        },
      });

      final bowl = Bowl.fromRecord(record);

      expect(bowl.camera, isNotNull);
      expect(bowl.camera!.pbId, 'cam_1');
      expect(bowl.camera!.frigateName, 'zero1');
    });
  });
}
