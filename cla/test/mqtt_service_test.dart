import 'package:flutter_test/flutter_test.dart';
import 'package:food_bowl/models/bowl.dart';
import 'package:food_bowl/services/mqtt_service.dart';

void main() {
  group('MqttService.handleMessage', () {
    late MqttService service;

    setUp(() {
      service = MqttService(wsUrl: 'ws://test/mqtt', topicPrefix: 'home/foodbowl');
    });

    test('maps a status "open" payload to LidState.open with the bowl id', () {
      String? gotId;
      LidState? gotState;
      service.onLidStateChanged = (id, state) {
        gotId = id;
        gotState = state;
      };

      service.handleMessage('home/foodbowl/abc123/status', 'open');

      expect(gotId, 'abc123');
      expect(gotState, LidState.open);
    });

    test('maps "closed" and falls back to unknown for unrecognised payloads', () {
      final states = <LidState>[];
      service.onLidStateChanged = (_, state) => states.add(state);

      service.handleMessage('home/foodbowl/b/status', 'closed');
      service.handleMessage('home/foodbowl/b/status', 'garbage');

      expect(states, [LidState.closed, LidState.unknown]);
    });

    test('routes "announce" to onAnnounce only', () {
      String? announced;
      var lidCalls = 0;
      service.onAnnounce = (id) => announced = id;
      service.onLidStateChanged = (_, __) => lidCalls++;

      service.handleMessage('home/foodbowl/dev42/announce', '');

      expect(announced, 'dev42');
      expect(lidCalls, 0);
    });

    test('ignores malformed topics with fewer than four segments', () {
      var called = false;
      service.onAnnounce = (_) => called = true;
      service.onLidStateChanged = (_, __) => called = true;

      service.handleMessage('home/foodbowl/onlythree', 'open');

      expect(called, isFalse);
    });
  });

  group('MqttService.publish', () {
    test('is a no-op while disconnected and never touches the client', () {
      final service = MqttService(wsUrl: 'ws://test/mqtt');

      // `connected` defaults to false. If the guard were missing, this would
      // throw a LateInitializationError on the uninitialised `_client`.
      expect(() => service.publish('bowl1', 'open'), returnsNormally);
    });
  });
}
