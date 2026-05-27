// lib/widgets/topbar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/theme_provider.dart';

class AppTopBar extends StatelessWidget {
  final UserModel user;
  final VoidCallback onMenuTap;
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;

  const AppTopBar({
    super.key,
    required this.user,
    required this.onMenuTap,
    required this.onLogout,
    required this.onThemeToggle,
  });

  // Breakpoints
  static const double _kMobile = 480;
  static const double _kTablet = 768;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final width = MediaQuery.of(context).size.width;

    final isMobile = width < _kMobile;
    final isTablet = width >= _kMobile && width < _kTablet;
    final isDesktop = width >= _kTablet;

    return Container(
      height: isMobile ? 48 : 52,
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Logo ──────────────────────────────────────────────
          _Logo(isDark: isDark, showText: !isMobile),

          // ── Menu toggle ───────────────────────────────────────
          _IconBtn(icon: Icons.menu, onTap: onMenuTap, isDark: isDark),

          const Spacer(),

          // ── Theme toggle ──────────────────────────────────────
          Consumer<ThemeProvider>(
            builder: (context, theme, _) => _IconBtn(
              icon: theme.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              onTap: onThemeToggle,
              isDark: isDark,
            ),
          ),

          const SizedBox(width: 6),

          // ── User pill ─────────────────────────────────────────
          _UserPill(
            user: user,
            isDark: isDark,
            showName: isTablet || isDesktop,
            showRole: isTablet || isDesktop,
            showTeam: isDesktop,
          ),

          const SizedBox(width: 6),

          // ── Sign out ──────────────────────────────────────────
          if (isMobile)
            _IconBtn(
              icon: Icons.logout,
              onTap: onLogout,
              isDark: isDark,
            )
          else
            _SignOutButton(onLogout: onLogout, isDark: isDark),

          SizedBox(width: isMobile ? 8 : 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final bool isDark;
  final bool showText;

  const _Logo({required this.isDark, required this.showText});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: showText ? 16 : 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accent2],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'ATF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 8),
            Text(
              'Air Task Flow',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Icon(
          icon,
          size: 17,
          color: isDark ? AppColors.darkText2 : AppColors.lightText2,
        ),
      ),
    );
  }
}

class _UserPill extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final bool showName;
  final bool showRole;
  final bool showTeam;

  const _UserPill({
    required this.user,
    required this.isDark,
    required this.showName,
    required this.showRole,
    required this.showTeam,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(name: user.name),
          if (showName) ...[
            const SizedBox(width: 7),
            Text(
              user.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
          if (showRole) ...[
            const SizedBox(width: 6),
            _RoleChip(role: user.role),
          ],
          if (showTeam && user.team.isNotEmpty) ...[
            const SizedBox(width: 4),
            _TeamChip(team: user.team),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accent2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'superadmin': (AppColors.roleSuperAdmin, const Color(0x1A7C3AED)),
      'sales': (AppColors.roleSales, const Color(0x1A2563EB)),
      'teamleader': (AppColors.roleTeamLeader, const Color(0x1AD97706)),
      'writer': (AppColors.roleWriter, const Color(0x1A059669)),
    };
    final (textColor, bg) =
        colors[role] ?? (AppColors.darkText2, AppColors.darkSurface3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String team;
  const _TeamChip({required this.team});

  @override
  Widget build(BuildContext context) {
    const colors = {
      'Red': (AppColors.teamRed, const Color(0x1AEF4444)),
      'Yellow': (AppColors.teamYellow, const Color(0x1AF59E0B)),
      'Blue': (AppColors.teamBlue, const Color(0x1A2563EB)),
    };
    final (textColor, bg) =
        colors[team] ?? (AppColors.darkText2, AppColors.darkSurface3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        '$team Team',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onLogout;
  final bool isDark;

  const _SignOutButton({required this.onLogout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return TextButton(
      onPressed: onLogout,
      style: TextButton.styleFrom(
        foregroundColor:
        isDark ? AppColors.darkText2 : AppColors.lightText2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: border),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Sign Out', style: TextStyle(fontSize: 12.5)),
    );
  }
}