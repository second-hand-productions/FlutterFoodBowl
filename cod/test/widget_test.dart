import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cod/main.dart';

void main() {
  testWidgets('shows MQTT connection and door controls', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FoodBowlApp(autoConnect: false));

    expect(find.text('Mosquitto Broker'), findsOneWidget);
    expect(find.text('Door Control'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
