import 'package:go_router/go_router.dart';

import 'package:fishing_app/features/home/presentation/home_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
