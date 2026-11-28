import 'dart:async';
import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'core/config/thresholds_config.dart';
import 'core/state/player_session_store.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
      };
      await ThresholdsConfig.loadFromAsset();
      await PlayerSessionStore.instance.loadFromDisk();
      runApp(const PushGardApp());
    },
    (error, stack) {
      debugPrint('PushGard uncaught async error: $error');
    },
  );
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
