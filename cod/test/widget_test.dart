import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cod/config/food_bowl_settings.dart';
import 'package:cod/main.dart';

void main() {
  test('builds compatibility topics for MAC-based bowl IDs', () {
    expect(
      compatibleBowlIds('bowl-aabbccddeeff'),
      containsAll(['bowl-aabbccddeeff', 'aabbccddeeff']),
    );
    expect(
      commandTopicsFor('bowl-aabbccddeeff'),
      containsAll([
        'foodbowl/bowl-aabbccddeeff/door/set',
        'home/foodbowl/aabbccddeeff/command',
      ]),
    );
  });

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
}
