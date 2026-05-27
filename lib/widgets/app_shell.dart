// lib/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/leads/leads_screen.dart';
import '../screens/deals/deals_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/users/users_screen.dart';
import '../screens/writer_perf/writer_perf_screen.dart';
import '../screens/audit/audit_screen.dart';
import '../screens/invoice/invoice_screen.dart';
import 'sidebar.dart';
import 'topbar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _currentPage = 'dashboard';
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(String page) {
    setState(() => _currentPage = page);
    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 'dashboard':
        return const DashboardScreen();
      case 'leads':
        return const LeadsScreen();
      case 'deals':
        return const DealsScreen();
      case 'tasks':
        return const TasksScreen();
      case 'mytasks':
        return const TasksScreen(myTasksOnly: true);
      case 'users':
        return const UsersScreen();
      case 'writerperf':
        return const WriterPerfScreen();
      case 'audit':
        return const AuditScreen();
      case 'invoice':
        return const InvoiceScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop
          ? null
          : Drawer(
              width: 220,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: AppSidebar(
                currentPage: _currentPage,
                onNavigate: _navigateTo,
                collapsed: false,
                user: user,
              ),
            ),
      body: Column(
        children: [
          AppTopBar(
            user: user,
            onMenuTap: isDesktop
                ? () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)
                : () => _scaffoldKey.currentState?.openDrawer(),
            onLogout: () => context.read<AuthProvider>().logout(),
            onThemeToggle: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _sidebarCollapsed ? 52 : 220,
                    child: AppSidebar(
                      currentPage: _currentPage,
                      onNavigate: _navigateTo,
                      collapsed: _sidebarCollapsed,
                      user: user,
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    child: _buildCurrentPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
