import 'package:flutter/material.dart';

import 'package:fishing_app/app/router/app_router.dart';
import 'package:fishing_app/app/theme/app_theme.dart';

class FishingApp extends StatelessWidget {
  const FishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: appRouter,
    );
  }
}