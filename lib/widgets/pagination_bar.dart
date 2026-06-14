// lib/widgets/pagination_bar.dart
//
// Drop-in pagination bar used by LeadsScreen, DealsScreen, TasksScreen.
// Shows: [← Prev]  Page N  [Next →]
// Prev is hidden on page 1. Next is hidden when hasMore == false.

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;      // 1-based
  final bool hasMore;         // true → show Next button
  final bool isLoading;       // disable buttons while fetching
  final VoidCallback? onPrev; // null on page 1
  final VoidCallback onNext;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.hasMore,
    required this.isLoading,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final border  = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final text2   = isDark ? AppColors.darkText2    : AppColors.lightText2;

    // Nothing to show on page 1 with no next page
    if (currentPage == 1 && !hasMore) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Prev button ──────────────────────────────
          if (currentPage > 1)
            _PageBtn(
              label: '← Prev',
              onTap: isLoading ? null : onPrev,
              surface: surface,
              border: border,
              text2: text2,
            ),

          if (currentPage > 1) const SizedBox(width: 12),

          // ── Page indicator ───────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isLoading)
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                )
              else
                const Icon(Icons.layers_outlined,
                    size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Page $currentPage',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent),
              ),
            ]),
          ),

          // ── Next button ──────────────────────────────
          if (hasMore) ...[
            const SizedBox(width: 12),
            _PageBtn(
              label: 'Next →',
              onTap: isLoading ? null : onNext,
              surface: surface,
              border: border,
              text2: text2,
            ),
          ],
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color surface;
  final Color border;
  final Color text2;

  const _PageBtn({
    required this.label,
    required this.onTap,
    required this.surface,
    required this.border,
    required this.text2,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: disabled ? surface.withOpacity(0.5) : surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: disabled ? text2.withOpacity(0.4) : text2),
        ),
      ),
    );
  }
}