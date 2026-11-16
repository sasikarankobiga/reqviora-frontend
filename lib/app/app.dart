import 'package:flutter/material.dart';
class ReqvioraApp extends StatelessWidget {
  const ReqvioraApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'REQVIORA',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4))),
    home: const Scaffold(body: Center(child: Text('REQVIORA • From Requirements to Reality'))),
  );
}
