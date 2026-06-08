import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'config.dart';
import 'services/bowl_service.dart';
import 'services/mqtt_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appConfig = await loadConfig();
  final pb = PocketBase(appConfig.pbUrl);
  runApp(
    FoodBowlApp(
      bowlService: BowlService(pb),
      mqttService: MqttService(wsUrl: appConfig.mqttWsUrl),
      camBase: appConfig.camBase,
    ),
  );
}

class FoodBowlApp extends StatelessWidget {
  const FoodBowlApp({
    super.key,
    required this.bowlService,
    required this.mqttService,
    required this.camBase,
  });

  final BowlService bowlService;
  final MqttService mqttService;
  final String camBase;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Bowl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: FoodBowlHome(
        bowlService: bowlService,
        mqttService: mqttService,
        camBase: camBase,
      ),
    );
  }
}
