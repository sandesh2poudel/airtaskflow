// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/user_model.dart';

class AppSidebar extends StatelessWidget {
  final String currentPage;
  final Function(String) onNavigate;
  final bool collapsed;
  final UserModel user;

  const AppSidebar({
    super.key,
    required this.currentPage,
    required this.onNavigate,
    required this.collapsed,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          if (!collapsed) _section('Main'),
          _navItem(context, 'dashboard', Icons.grid_view_rounded, 'Dashboard'),

          if (user.isSales || user.isAdmin) ...[
            if (!collapsed) _section('Sales'),
            _navItem(context, 'leads', Icons.fact_check_outlined, 'Data Collection'),
            _navItem(context, 'deals', Icons.attach_money_rounded, 'Deals Closed'),
            _navItem(context, 'mytasks', Icons.assignment_outlined, 'My Tasks'),
          ],

          if (user.isTeamLeader) ...[
            if (!collapsed) _section('Team'),
            _navItem(context, 'tasks', Icons.task_outlined, 'Writer Tasks'),
            _navItem(context, 'writerperf', Icons.bar_chart_rounded, 'Writer Stats'),
          ],

          if (user.isWriter) ...[
            if (!collapsed) _section('Work'),
            _navItem(context, 'tasks', Icons.edit_note_rounded, 'My Tasks'),
          ],

          if (user.isAdmin) ...[
            _navItem(context, 'tasks', Icons.task_outlined, 'All Tasks'),
            _navItem(context, 'writerperf', Icons.bar_chart_rounded, 'Writer Stats'),
            _navItem(context, 'invoice', Icons.receipt_long_outlined, 'Invoice'),
            if (!collapsed) _section('Admin'),
            _navItem(context, 'users', Icons.group_outlined, 'Users'),
            _navItem(context, 'audit', Icons.history_rounded, 'Audit Log'),
          ],
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText3,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, String id, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = currentPage == id;
    final textColor = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final activeTextColor = AppColors.accent;

    return GestureDetector(
      onTap: () => onNavigate(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment:
              collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon,
              size: 17,
              color: isActive ? activeTextColor : textColor,
            ),
            if (!collapsed) ...[
              const SizedBox(width: 9),
              Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeTextColor : textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
