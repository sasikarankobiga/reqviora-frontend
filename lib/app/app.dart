import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'router/route_paths.dart';

class ReqvioraApp extends StatelessWidget {
  const ReqvioraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REQVIORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
      ),
      initialRoute: RoutePaths.dashboard,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
