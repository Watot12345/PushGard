import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ButtonVariant { primary, gold, secondary, outline }

/// Official PushGard Button matching Pages 3, 4, and 6 of `Pushgard — Logo & App Icon.pdf`.
/// Primary: Electric Volt Lime (#D4FF2A) with dark carbon (#0B0B0F) tracked text.
/// Secondary: Dark Slate (#1B1A26) with crisp white (#FFFFFF) tracked text.
class PushGardButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;

  const PushGardButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 58,
  });

  @override
  State<PushGardButton> createState() => _PushGardButtonState();
}

class _PushGardButtonState extends State<PushGardButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    Color? borderColor;

    switch (widget.variant) {
      case ButtonVariant.primary:
      case ButtonVariant.gold:
        bg = AppColors.volt;
        textColor = AppColors.background;
        borderColor = null;
        break;
      case ButtonVariant.secondary:
        bg = AppColors.surface;
        textColor = AppColors.textPrimary;
        borderColor = null;
        break;
      case ButtonVariant.outline:
        bg = AppColors.surface;
        textColor = AppColors.textSecondary;
        borderColor = AppColors.border;
        break;
    }

    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isEnabled ? bg : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: textColor,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color:
                                  isEnabled ? textColor : AppColors.textMuted,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text.toUpperCase(),
                            style: AppTypography.cardHeadline(
                              color:
                                  isEnabled ? textColor : AppColors.textMuted,
                            ).copyWith(
                              fontSize: 16,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
