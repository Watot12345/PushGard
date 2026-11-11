import 'package:flutter/material.dart';
import '../config/thresholds_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class RankTierInfo {
  final String tierRoman;
  final String title;
  final String subtitle;
  final Color color;
  final Color secondaryColor;
  final Color bg;
  final int minEgo;
  final int? nextTierEgo;
  final String? nextTierTitle;

  const RankTierInfo({
    required this.tierRoman,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.secondaryColor,
    required this.bg,
    required this.minEgo,
    this.nextTierEgo,
    this.nextTierTitle,
  });

  static RankTierInfo fromScore(int egoRating, {ThresholdsConfig? config}) {
    final cfg = config ?? ThresholdsConfig.instance;
    if (egoRating >= cfg.rankTierGodOfWarMinEgo) {
      return RankTierInfo(
        tierRoman: 'DIVISION V',
        title: 'GOD OF WAR',
        subtitle: 'Apex Grandmaster',
        color: AppColors.volt,
        secondaryColor: AppColors.voltOlive,
        bg: AppColors.goldGlow,
        minEgo: cfg.rankTierGodOfWarMinEgo,
        nextTierEgo: null,
        nextTierTitle: 'APEX LEGEND',
      );
    } else if (egoRating >= cfg.rankTierTitanMinEgo) {
      return RankTierInfo(
        tierRoman: 'DIVISION IV',
        title: 'TITAN II',
        subtitle: 'Promotion Zone Elite',
        color: AppColors.volt,
        secondaryColor: AppColors.voltOlive,
        bg: AppColors.goldGlow,
        minEgo: cfg.rankTierTitanMinEgo,
        nextTierEgo: cfg.rankTierGodOfWarMinEgo,
        nextTierTitle: 'GOD OF WAR',
      );
    } else if (egoRating >= cfg.rankTierVanguardMinEgo) {
      return RankTierInfo(
        tierRoman: 'DIVISION III',
        title: 'VANGUARD',
        subtitle: 'Ranked Contender',
        color: AppColors.volt,
        secondaryColor: AppColors.voltOlive,
        bg: AppColors.goldGlow,
        minEgo: cfg.rankTierVanguardMinEgo,
        nextTierEgo: cfg.rankTierTitanMinEgo,
        nextTierTitle: 'TITAN II',
      );
    } else if (egoRating >= cfg.rankTierSpartanMinEgo) {
      return RankTierInfo(
        tierRoman: 'DIVISION II',
        title: 'SPARTAN',
        subtitle: 'Arena Fighter',
        color: AppColors.volt,
        secondaryColor: AppColors.voltOlive,
        bg: AppColors.goldGlow,
        minEgo: cfg.rankTierSpartanMinEgo,
        nextTierEgo: cfg.rankTierVanguardMinEgo,
        nextTierTitle: 'VANGUARD',
      );
    } else {
      return RankTierInfo(
        tierRoman: 'DIVISION I',
        title: 'IRON GUARD',
        subtitle: 'Challenger',
        color: AppColors.textSecondary,
        secondaryColor: AppColors.voltOlive,
        bg: const Color(0x3364748B),
        minEgo: cfg.eloRatingFloor,
        nextTierEgo: cfg.rankTierSpartanMinEgo,
        nextTierTitle: 'SPARTAN',
      );
    }
  }

  double progressToNextTier(int egoRating) {
    if (nextTierEgo == null) return 1.0;
    final span = (nextTierEgo! - minEgo).clamp(1, 10000);
    return ((egoRating - minEgo) / span).clamp(0.0, 1.0);
  }

  int egoNeededForNextTier(int egoRating) {
    if (nextTierEgo == null) return 0;
    return (nextTierEgo! - egoRating).clamp(0, 10000);
  }
}

/// Official PushGard Heraldic Shield Mark from Page 1 & Page 2 of `Pushgard — Logo & App Icon.pdf`.
/// Solid Volt Lime (#D4FF2A) shield with Olive (#6E7F29) top chevron and Carbon (#101114) bottom chevron.
class RankShieldCrest extends StatelessWidget {
  final int egoScore;
  final double size;
  final bool inverted;

  const RankShieldCrest({
    super.key,
    this.egoScore = 1780,
    this.size = 36,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PushGardOfficialShieldPainter(inverted: inverted),
      ),
    );
  }
}

class _PushGardOfficialShieldPainter extends CustomPainter {
  final bool inverted;

  _PushGardOfficialShieldPainter({required this.inverted});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Curved heraldic shield matching Page 1 & 2 of Pushgard PDF
    final shieldPath = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.88, h * 0.21)
      ..lineTo(w * 0.88, h * 0.53)
      ..cubicTo(w * 0.88, h * 0.78, w * 0.50, h * 0.94, w * 0.50, h * 0.94)
      ..cubicTo(w * 0.50, h * 0.94, w * 0.12, h * 0.78, w * 0.12, h * 0.53)
      ..lineTo(w * 0.12, h * 0.21)
      ..close();

    final shieldPaint = Paint()
      ..color = inverted ? AppColors.shieldCarbon : AppColors.volt
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, shieldPaint);

    // Top Chevron: Olive Green (#6E7F29)
    final topChevron = Path()
      ..moveTo(w * 0.28, h * 0.53)
      ..lineTo(w * 0.50, h * 0.31)
      ..lineTo(w * 0.72, h * 0.53)
      ..lineTo(w * 0.65, h * 0.60)
      ..lineTo(w * 0.50, h * 0.45)
      ..lineTo(w * 0.35, h * 0.60)
      ..close();
    canvas.drawPath(
      topChevron,
      Paint()..color = AppColors.voltOlive,
    );

    // Bottom Chevron: Carbon Black (#101114) on Volt shield, or Volt (#D4FF2A) on dark shield
    final bottomChevron = Path()
      ..moveTo(w * 0.28, h * 0.69)
      ..lineTo(w * 0.50, h * 0.47)
      ..lineTo(w * 0.72, h * 0.69)
      ..lineTo(w * 0.65, h * 0.76)
      ..lineTo(w * 0.50, h * 0.61)
      ..lineTo(w * 0.35, h * 0.76)
      ..close();
    canvas.drawPath(
      bottomChevron,
      Paint()..color = inverted ? AppColors.volt : AppColors.shieldCarbon,
    );
  }

  @override
  bool shouldRepaint(covariant _PushGardOfficialShieldPainter oldDelegate) {
    return oldDelegate.inverted != inverted;
  }
}

class RankBadge extends StatelessWidget {
  final int egoScore;
  final bool compact;

  const RankBadge({
    super.key,
    required this.egoScore,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tier = RankTierInfo.fromScore(egoScore);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.volt.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RankShieldCrest(size: 16),
            const SizedBox(width: 6),
            Text(
              tier.title,
              style: AppTypography.tacticalBadge(color: AppColors.volt),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.volt.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RankShieldCrest(size: 26),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tier.tierRoman,
                style: AppTypography.telemetryCode(color: AppColors.volt, fontSize: 9),
              ),
              Text(
                tier.title,
                style: AppTypography.cardHeadline(color: Colors.white).copyWith(fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
