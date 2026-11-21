
import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';

class ReqvioraApp extends StatelessWidget {
  const ReqvioraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'REQVIORA',
      debugShowCheckedModeBanner: false,

      // REQVIORA professional theme
      theme: AppTheme.lightTheme,

      // Navigation system
      routerConfig: appRouter,
    );
  }
}
