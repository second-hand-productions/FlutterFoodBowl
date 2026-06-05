import 'package:flutter/material.dart';

import 'app/food_bowl_app.dart';
import 'config/food_bowl_settings.dart';

export 'app/food_bowl_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFoodBowlSettings();
  runApp(const FoodBowlApp());
}
