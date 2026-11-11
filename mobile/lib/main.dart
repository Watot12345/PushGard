import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'core/config/thresholds_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThresholdsConfig.loadFromAsset();
  runApp(const PushGardApp());
}

class PushGardApp extends StatelessWidget {
  const PushGardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PushGard — EGO Ranking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppShell(),
    );
  }
}
