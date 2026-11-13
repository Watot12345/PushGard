import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_colors.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/match/screens/framing_screen.dart';
import 'spike/spike_screen.dart';

/// App navigation shell with icon-based bottom bar
/// (Home · Battle · Ranks · Profile) and Volt Lime active indicator.
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
          key: const ValueKey('tab_home'),
          onOpenSpike: () {
            setState(() => _currentIndex = 3);
          },
        );
      case 1:
        return const FramingScreen(
          key: ValueKey('tab_battle'),
          isBattle: true,
        );
      case 2:
        return const HistoryScreen(key: ValueKey('tab_ranks'));
      case 3:
      default:
        return const SpikeScreen(key: ValueKey('tab_profile'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildActiveTab(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.surface, width: 1.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(
                label: 'HOME',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                index: 0,
              ),
              _buildNavIcon(
                label: 'BATTLE',
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt_rounded,
                index: 1,
                isPrimaryAction: true,
              ),
              _buildNavIcon(
                label: 'RANKS',
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events_rounded,
                index: 2,
              ),
              _buildNavIcon(
                label: 'PROFILE',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required int index,
    bool isPrimaryAction = false,
  }) {
    final isSelected = _currentIndex == index;
    final Color iconColor = isPrimaryAction
        ? AppColors.background
        : (isSelected ? AppColors.volt : AppColors.textSecondary);

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
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
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1.0,
              child: AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: isPrimaryAction ? 18 : 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isPrimaryAction
                        ? AppColors.volt
                        : (isSelected
                            ? AppColors.volt.withValues(alpha: 0.14)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected || isPrimaryAction ? activeIcon : icon,
                        color: iconColor,
                        size: isPrimaryAction ? 26 : 24,
                      ),
                      if (isSelected && !isPrimaryAction) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.volt,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
