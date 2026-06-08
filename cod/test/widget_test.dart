import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cod/main.dart';
import 'package:cod/models/bowl_models.dart';
import 'package:cod/models/camera_models.dart';
import 'package:cod/services/bowls/bowl_repository.dart';
import 'package:cod/services/cameras/camera_feed_repository.dart';

void main() {
  testWidgets('adds bowl controls from the UI', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const FoodBowlApp(autoConnect: false, usePocketBase: false),
    );

    expect(find.text('Mosquitto Broker'), findsOneWidget);
    expect(find.text('ws://cod.lan/mqtt'), findsOneWidget);
    expect(find.text('No bowls added'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);

    await tester.tap(find.text('Add bowl').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Bowl ID'), 'kitchen');
    await tester.enterText(find.bySemanticsLabel('Display name'), 'Kitchen');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('kitchen'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename bowl'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Display name'), 'Pantry');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pantry'), findsOneWidget);
    expect(find.text('Kitchen'), findsNothing);
  });

  testWidgets('loads bowls from injected repository', (tester) async {
    await tester.pumpWidget(
      FoodBowlApp(
        autoConnect: false,
        bowlRepository: FakeBowlRepository([
          const FoodBowlConfig(
            recordId: 'record-kitchen',
            id: 'kitchen',
            name: 'Kitchen',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
  });

  testWidgets('opens camera feed for bowl', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const bowl = FoodBowlConfig(
      recordId: 'record-kitchen',
      id: 'kitchen',
      name: 'Kitchen',
    );

    await tester.pumpWidget(
      FoodBowlApp(
        autoConnect: false,
        bowlRepository: FakeBowlRepository([bowl]),
        cameraFeedRepository: FakeCameraFeedRepository(
          CameraFeed(
            recordId: 'camera-kitchen',
            name: 'Kitchen Camera',
            displayUri: Uri.parse('http://cod.lan/frigate/api/kitchen'),
            kind: CameraFeedKind.mjpeg,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('View camera'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Camera'), findsOneWidget);
    expect(find.text('http://cod.lan/frigate/api/kitchen'), findsOneWidget);
  });
}

class FakeBowlRepository implements BowlRepository {
  FakeBowlRepository(this.bowls);

  final List<FoodBowlConfig> bowls;

  @override
  Future<List<FoodBowlConfig>> loadBowls() async => bowls;

  @override
  Future<FoodBowlConfig?> findBowl(String bowlId) async {
    for (final bowl in bowls) {
      if (bowl.id == bowlId) {
        return bowl;
      }
    }
    return null;
  }

  @override
  Future<FoodBowlConfig> createBowl(FoodBowlConfig bowl) async {
    final savedBowl = bowl.copyWith(recordId: 'record-${bowl.id}');
    bowls.add(savedBowl);
    return savedBowl;
  }

  @override
  Future<void> deleteBowl(FoodBowlConfig bowl) async {
    bowls.removeWhere((savedBowl) => savedBowl.id == bowl.id);
  }

  @override
  Future<FoodBowlConfig?> renameBowl(FoodBowlConfig bowl, String name) async {
    for (var index = 0; index < bowls.length; index += 1) {
      if (bowls[index].id == bowl.id) {
        final renamedBowl = bowls[index].copyWith(name: name);
        bowls[index] = renamedBowl;
        return renamedBowl;
      }
    }
    return null;
  }
}

class FakeCameraFeedRepository implements CameraFeedRepository {
  const FakeCameraFeedRepository(this.feed);

  final CameraFeed? feed;

  @override
  Future<CameraFeed?> findFeedForBowl(FoodBowlConfig bowl) async => feed;
}
