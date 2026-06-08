import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:food_bowl/models/camera.dart';

void main() {
  group('Camera', () {
    test('fromRecord reads id and frigate_name', () {
      final record = RecordModel({'id': 'cam_1', 'frigate_name': 'zero1'});

      final camera = Camera.fromRecord(record);

      expect(camera.pbId, 'cam_1');
      expect(camera.frigateName, 'zero1');
    });

    test('snapshotUrl builds the Frigate latest.jpg path', () {
      const camera = Camera(pbId: 'cam_1', frigateName: 'zero1');

      expect(
        camera.snapshotUrl('https://host/frigate'),
        'https://host/frigate/api/zero1/latest.jpg',
      );
    });
  });
}
