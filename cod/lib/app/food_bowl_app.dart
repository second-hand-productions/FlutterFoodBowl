import 'package:flutter/material.dart';

import 'package:cod/features/home/food_bowl_home_page.dart';

class FoodBowlApp extends StatelessWidget {
  const FoodBowlApp({
    super.key,
    this.autoConnect = true,
    this.usePocketBase = true,
  });

  final bool autoConnect;
  final bool usePocketBase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E7E67),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Food Bowl',
      theme: ThemeData(
        colorScheme: colorScheme,
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: FoodBowlHomePage(
        autoConnect: autoConnect,
        usePocketBase: usePocketBase,
      ),
    );
  }
}
