import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/match/screens/framing_screen.dart';
import 'spike/spike_screen.dart';

/// App navigation shell matching the bottom bar in Page 3 of `Pushgard — Logo & App Icon.pdf`
/// (HOME · BATTLE · RANKS · PROFILE/SPIKE) with Volt Lime active highlight.
/// Only mounts the active tab so camera sensors are never started in the background on launch.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  Widget _buildActiveTab() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onOpenSpike: () {
            setState(() => _currentIndex = 3);
          },
        );
      case 1:
        return const FramingScreen(isBattle: true);
      case 2:
        return const HistoryScreen();
      case 3:
      default:
        return const SpikeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildActiveTab(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.surface, width: 1.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavLabel('HOME', 0),
              _buildNavLabel('BATTLE', 1),
              _buildNavLabel('RANKS', 2),
              _buildNavLabel('PROFILE', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavLabel(String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FramingScreen(isBattle: true),
              ),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTypography.telemetryCode(
                color: isSelected ? AppColors.volt : AppColors.textSecondary,
                fontSize: 13,
              ).copyWith(letterSpacing: 1.8),
            ),
          ),
        ),
      ),
    );
  }
}
