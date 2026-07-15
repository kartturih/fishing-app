import 'package:go_router/go_router.dart';

import 'package:fishing_app/features/map/presentation/map_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
