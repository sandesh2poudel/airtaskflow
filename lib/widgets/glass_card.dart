// lib/widgets/glass_card.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderRadius;
  final Color? topAccentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 12,
    this.topAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topAccentColor != null)
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: topAccentColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class CardHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const CardHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
