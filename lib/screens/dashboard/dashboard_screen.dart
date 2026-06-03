// lib/screens/dashboard/dashboard_screen.dart
// Modernized UI — glassmorphism cards, gradient accents, animated elements
// Supports dark & light mode. Zero functional changes.
// UPDATED: Leaderboard has its own Year (2026-2029) + Month filter
// RESPONSIVE FIX: stat cards, header, date filter bar — mobile safe
// NEW: Payment amount summary row (Pending / Partial / Paid) below stat cards
// FIX: All currency values show full numbers (no K/M suffix)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

// ── Design helpers ──────────────────────────────────────────────
class _DS {
  static BoxDecoration glass({
    required bool isDark,
    BorderRadius? radius,
    Color? tint,
  }) {
    return BoxDecoration(
      color: isDark
          ? (tint ?? const Color(0xFF151820)).withOpacity(0.82)
          : (tint ?? Colors.white).withOpacity(0.80),
      borderRadius: radius ?? BorderRadius.circular(20),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.85),
        width: 1.2,
      ),
      boxShadow: isDark
          ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.accent.withOpacity(0.04),
          blurRadius: 40,
          offset: const Offset(0, 0),
        ),
      ]
          : [
        BoxShadow(
          color: AppColors.accent.withOpacity(0.08),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.9),
          blurRadius: 1,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  static LinearGradient bgGradient(bool isDark) => LinearGradient(
    colors: isDark
        ? [
      const Color(0xFF0D0F14),
      const Color(0xFF0F1219),
      const Color(0xFF111520),
    ]
        : [
      const Color(0xFFEEF2FF),
      const Color(0xFFF0F9FF),
      const Color(0xFFFAFAFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accentGrad = const LinearGradient(
    colors: [AppColors.accent, Color(0xFF4F8EF7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient greenGrad = const LinearGradient(
    colors: [AppColors.green, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient purpleGrad = const LinearGradient(
    colors: [AppColors.accent2, Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient yellowGrad = const LinearGradient(
    colors: [AppColors.yellow, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoGrad = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGrad = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Screen ──────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FirestoreService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _leaderboard = [];
  String _lbPeriod = '';
  bool _loading = true;

  String? _selectedYear = DateTime.now().year.toString();
  String? _selectedMonth = () {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }();

  String? _lbSelectedYear;
  String? _lbSelectedMonth;

  static const List<String> _lbYears = ['2026', '2027', '2028', '2029'];

  static const Map<String, String> _monthLabels = {
    '01': 'Jan', '02': 'Feb', '03': 'Mar', '04': 'Apr',
    '05': 'May', '06': 'Jun', '07': 'Jul', '08': 'Aug',
    '09': 'Sep', '10': 'Oct', '11': 'Nov', '12': 'Dec',
  };

  String get _activeFilter {
    if (_selectedMonth != null) return _selectedMonth!;
    if (_selectedYear != null) return _selectedYear!;
    return '';
  }

  String get _lbFilter {
    if (_lbSelectedMonth != null) return _lbSelectedMonth!;
    if (_lbSelectedYear != null) return _lbSelectedYear!;
    return '';
  }

  List<String> get _yearList {
    final now = DateTime.now();
    final years = <String>[];
    for (int y = 2026; y <= now.year + 3; y++) {
      years.add(y.toString());
    }
    return years;
  }

  List<String> _monthsForYear(String year) {
    final months = <String>[];
    for (int m = 1; m <= 12; m++) {
      months.add('$year-${m.toString().padLeft(2, '0')}');
    }
    return months;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().currentUser!;
    try {
      final results = await Future.wait([
        _svc.getDashboardStats(user, filter: _activeFilter),
        _svc.getMonthlyChartData(user, filter: _activeFilter),
        _svc.getLeaderboardData(user, _lbPeriod, filter: _lbFilter),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _chartData = results[1] as List<Map<String, dynamic>>;
          _leaderboard = results[2] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadLeaderboard() async {
    final user = context.read<AuthProvider>().currentUser!;
    try {
      final lb = await _svc.getLeaderboardData(
        user,
        _lbPeriod,
        filter: _lbFilter,
      );
      if (mounted) setState(() => _leaderboard = lb);
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════
  // ── GLOBAL number formatter — always full integer with commas ───
  // e.g. 3800 → "3,800"  |  150000 → "150,000"  |  224 → "224"
  // ════════════════════════════════════════════════════════════════
  String _fmtAmt(double v) {
    final intVal = v.toInt();
    final s = intVal.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final text2 = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Container(
      decoration: BoxDecoration(gradient: _DS.bgGradient(isDark)),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 28 : 16,
          vertical: 22,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(user, isDark, textColor, text2),
                const SizedBox(height: 20),
                _buildDateFilterBar(isDark, textColor, text2),
                const SizedBox(height: 22),
                if (_loading)
                  _buildLoadingState(isDark)
                else ...[
                  _buildStatCards(user, isDark),
                  const SizedBox(height: 16),
                  if (!user.isWriter)
                    _buildPaymentAmountRow(isDark, textColor, text2),
                  const SizedBox(height: 20),
                  if (!user.isWriter && _chartData.isNotEmpty) ...[
                    _buildChartCard(isDark, textColor, text2),
                    const SizedBox(height: 20),
                  ],
                  if ((user.isAdmin || user.isTeamLeader) &&
                      _leaderboard.isNotEmpty) ...[
                    _buildLeaderboardCard(isDark, textColor, text2),
                    const SizedBox(height: 20),
                  ],
                  if (!user.isWriter)
                    _buildFunnelCard(isDark, textColor, text2),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader(
      UserModel user, bool isDark, Color textColor, Color text2) {
    final hour = DateTime.now().hour;
    final greeting =
    hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final greetEmoji = hour < 12 ? '🌤️' : hour < 17 ? '☀️' : '🌙';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '$greeting, ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        _DS.accentGrad.createShader(bounds),
                    child: Text(
                      '${user.name}!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(greetEmoji, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s what\'s happening with your business today.',
                style: TextStyle(fontSize: 12.5, color: text2),
              ),
            ],
          ),
        ),
        _refreshBtn(isDark),
      ],
    );
  }

  Widget _refreshBtn(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _load,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.35),
                ),
              ),
              child: const Row(children: [
                Icon(Icons.refresh_rounded, size: 15, color: AppColors.accent),
                SizedBox(width: 6),
                Text(
                  'Refresh',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Dashboard-wide date filter bar ──────────────────────────────
  Widget _buildDateFilterBar(bool isDark, Color textColor, Color text2) {
    String activeLabel = 'All Time';
    if (_selectedMonth != null) {
      final parts = _selectedMonth!.split('-');
      activeLabel = '${_monthLabels[parts[1]] ?? ''} ${parts[0]}';
    } else if (_selectedYear != null) {
      activeLabel = _selectedYear!;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration:
          _DS.glass(isDark: isDark, radius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Period',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text2,
                  ),
                ),
                const SizedBox(width: 12),
                _filterChip(
                  label: 'All Time',
                  isActive: _selectedYear == null && _selectedMonth == null,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _selectedYear = null;
                      _selectedMonth = null;
                    });
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _yearDropdown(isDark, text2),
                const SizedBox(width: 8),
                if (_selectedYear != null) ...[
                  _monthDropdown(isDark, text2),
                  const SizedBox(width: 8),
                ],
                const SizedBox(width: 8),
                if (_selectedYear != null || _selectedMonth != null)
                  _activeBadge(activeLabel, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: _DS.accentGrad,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedYear = null;
                _selectedMonth = null;
              });
              _load();
            },
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child:
              const Icon(Icons.close_rounded, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive ? _DS.accentGrad : null,
          color: isActive
              ? null
              : (isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.accent
                : (isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08)),
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive
                ? Colors.white
                : (isDark ? AppColors.darkText2 : AppColors.lightText2),
          ),
        ),
      ),
    );
  }

  Widget _yearDropdown(bool isDark, Color text2) {
    final isActive = _selectedYear != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withOpacity(0.12)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.accent.withOpacity(0.5)
                  : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedYear,
              hint: Text(
                'Year',
                style: TextStyle(
                  fontSize: 11,
                  color: text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? AppColors.accent : text2,
              ),
              dropdownColor:
              isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.accent
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              items: _yearList
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedYear = val;
                  _selectedMonth = null;
                });
                _load();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthDropdown(bool isDark, Color text2) {
    final isActive = _selectedMonth != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withOpacity(0.12)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.accent.withOpacity(0.5)
                  : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMonth,
              hint: Text(
                'Month',
                style: TextStyle(
                  fontSize: 11,
                  color: text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? AppColors.accent : text2,
              ),
              dropdownColor:
              isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.accent
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              items: _monthsForYear(_selectedYear!).map((m) {
                final parts = m.split('-');
                final label = _monthLabels[parts[1]] ?? parts[1];
                return DropdownMenuItem(value: m, child: Text(label));
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedMonth = val);
                _load();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading state ───────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.2,
          children: List.generate(
            4,
                (_) => ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: _DS.glass(
                      isDark: isDark, radius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading dashboard…',
          style: TextStyle(
            color: isDark ? AppColors.darkText2 : AppColors.lightText2,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ── Stat cards ──────────────────────────────────────────────────
  Widget _buildStatCards(UserModel user, bool isDark) {
    final cards = <_StatDef>[];

    if (!user.isTeamLeader && !user.isWriter) {
      cards.add(_StatDef(
        'Total Leads',
        _stats['totalLeads']?.toString() ?? '0',
        Icons.fact_check_outlined,
        AppColors.accent,
        _DS.accentGrad,
        'leads tracked',
      ));
      cards.add(_StatDef(
        'Total Deals',
        _stats['totalDeals']?.toString() ?? '0',
        Icons.handshake_outlined,
        AppColors.green,
        _DS.greenGrad,
        'deals closed',
      ));
      final rev = (_stats['totalRevenue'] as double? ?? 0.0);
      cards.add(_StatDef(
        'Revenue (AUD)',
        '\$${_fmtAmt(rev)}',           // ← full number with commas
        Icons.trending_up_rounded,
        AppColors.accent2,
        _DS.purpleGrad,
        'total earned',
      ));
      cards.add(_StatDef(
        'Pending Payment',
        _stats['pendingPayment']?.toString() ?? '0',
        Icons.pending_outlined,
        AppColors.yellow,
        _DS.yellowGrad,
        'awaiting payment',
      ));
    } else if (user.isTeamLeader) {
      cards.add(_StatDef(
        'Total Deals',
        _stats['totalDeals']?.toString() ?? '0',
        Icons.handshake_outlined,
        AppColors.green,
        _DS.greenGrad,
        'deals closed',
      ));
      final rev = (_stats['totalRevenue'] as double? ?? 0.0);
      cards.add(_StatDef(
        'Team Revenue',
        '\$${_fmtAmt(rev)}',           // ← full number with commas
        Icons.trending_up_rounded,
        AppColors.accent2,
        _DS.purpleGrad,
        'total earned',
      ));
    }

    cards.add(_StatDef(
      'Tasks Pending',
      _stats['tasksPending']?.toString() ?? '0',
      Icons.access_time_rounded,
      AppColors.yellow,
      _DS.yellowGrad,
      'need attention',
    ));
    cards.add(_StatDef(
      'Tasks Done',
      _stats['tasksCompleted']?.toString() ?? '0',
      Icons.check_circle_outline_rounded,
      AppColors.green,
      _DS.greenGrad,
      'completed',
    ));

    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW >= 720;
    final isMid = screenW >= 480;
    final crossCount = isWide ? 4 : 2;
    final aspectRatio = isWide ? 1.85 : isMid ? 1.55 : 1.30;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: cards.map((c) => _statCard(c, isDark)).toList(),
    );
  }

  Widget _statCard(_StatDef c, bool isDark) {
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 400;
    final iconSize = isNarrow ? 36.0 : 44.0;
    final valueFontSize = isNarrow ? 20.0 : 26.0;
    final labelFontSize = isNarrow ? 8.5 : 9.5;
    final hPad = isNarrow ? 10.0 : 16.0;
    final iconInnerSize = isNarrow ? 18.0 : 22.0;
    final gapBetween = isNarrow ? 8.0 : 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? c.color.withOpacity(0.08)
                : c.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: c.color.withOpacity(isDark ? 0.18 : 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.color.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: c.gradient,
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                ),
              ),
              Positioned(
                right: -18,
                bottom: -18,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.color.withOpacity(0.07),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad - 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.color.withOpacity(0.2),
                            c.color.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border:
                        Border.all(color: c.color.withOpacity(0.2)),
                      ),
                      child: Icon(c.icon, color: c.color, size: iconInnerSize),
                    ),
                    SizedBox(width: gapBetween),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            c.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.lightText2,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (b) => c.gradient.createShader(b),
                            child: Text(
                              c.value,
                              style: TextStyle(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.sub,
                            style: TextStyle(
                              fontSize: isNarrow ? 9.0 : 10.0,
                              color: c.color.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── Payment Amount Summary Row ───────────────────────────────────
  // ════════════════════════════════════════════════════════════════
  Widget _buildPaymentAmountRow(bool isDark, Color textColor, Color text2) {
    final pendingAmt = _stats['pendingAmount'] as double? ?? 0.0;
    final partialAmt = _stats['partialAmount'] as double? ?? 0.0;
    final paidAmt    = _stats['paidAmount']    as double? ?? 0.0;

    final amountCards = [
      _AmountDef(
        label: 'Pending Amount',
        value: '\$${_fmtAmt(pendingAmt)}',     // ← full number
        subtitle: 'awaiting full payment',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF59E0B),
        gradient: _DS.amberGrad,
        emoji: '⏳',
      ),
      _AmountDef(
        label: 'Partial Amount',
        value: '\$${_fmtAmt(partialAmt)}',     // ← full number
        subtitle: 'partially received',
        icon: Icons.pie_chart_outline_rounded,
        color: const Color(0xFF6366F1),
        gradient: _DS.indigoGrad,
        emoji: '🔀',
      ),
      _AmountDef(
        label: 'Paid Amount',
        value: '\$${_fmtAmt(paidAmt)}',        // ← full number
        subtitle: 'fully collected',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF22C55E),
        gradient: _DS.greenGrad,
        emoji: '✅',
      ),
    ];

    final screenW = MediaQuery.of(context).size.width;
    final isWide  = screenW >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: _DS.greenGrad,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (_activeFilter.isNotEmpty) _filterBadgeSmall(_activeFilter),
            ],
          ),
        ),

        if (isWide)
          Row(
            children: amountCards
                .map((c) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: c == amountCards.last ? 0 : 12,
                ),
                child: _amountCard(c, isDark, text2),
              ),
            ))
                .toList(),
          )
        else
          Column(
            children: amountCards
                .map((c) => Padding(
              padding: EdgeInsets.only(
                bottom: c == amountCards.last ? 0 : 12,
              ),
              child: _amountCard(c, isDark, text2),
            ))
                .toList(),
          ),
      ],
    );
  }

  Widget _amountCard(_AmountDef c, bool isDark, Color text2) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: isDark
                ? c.color.withOpacity(0.09)
                : c.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: c.color.withOpacity(isDark ? 0.22 : 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: c.color.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -14,
                left: -16,
                right: -16,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: c.gradient,
                  ),
                ),
              ),
              Positioned(
                right: -14,
                bottom: -14,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.color.withOpacity(0.08),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          c.color.withOpacity(0.22),
                          c.color.withOpacity(0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: c.color.withOpacity(0.25)),
                    ),
                    child: Center(
                      child: Text(c.emoji,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkText2
                                : AppColors.lightText2,
                            letterSpacing: 0.7,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (b) => c.gradient.createShader(b),
                          child: Text(
                            c.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: c.color.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Revenue chart ───────────────────────────────────────────────
  Widget _buildChartCard(bool isDark, Color textColor, Color text2) {
    final gridColor =
    isDark ? const Color(0x12FFFFFF) : const Color(0x12000000);

    final labels = _chartData.map((d) {
      final parts = (d['month'] as String).split('-');
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = int.tryParse(parts[1]) ?? 1;
      return '${months[m - 1]} \'${parts[0].substring(2)}';
    }).toList();

    final spots = _chartData
        .asMap()
        .entries
        .map((e) =>
        FlSpot(e.key.toDouble(), (e.value['revenue'] as double)))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration:
          _DS.glass(isDark: isDark, radius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: _DS.accentGrad,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.show_chart_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue Overview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        if (_activeFilter.isNotEmpty)
                          _filterBadgeSmall(_activeFilter),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 190,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: gridColor, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (v, _) => Text(
                            '\$${_fmtAmt(v)}',   // ← full number on chart axis
                            style: TextStyle(fontSize: 10, color: text2),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= labels.length)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                labels[idx],
                                style: TextStyle(fontSize: 9, color: text2),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.isEmpty
                            ? [const FlSpot(0, 0)]
                            : spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        gradient: _DS.accentGrad,
                        barWidth: 3,
                        dotData: FlDotData(
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.accent,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withOpacity(0.18),
                              AppColors.accent.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBadgeSmall(String filter) {
    String label = filter;
    if (filter.length == 7) {
      final parts = filter.split('-');
      label = '${_monthLabels[parts[1]] ?? ''} ${parts[0]}';
    }
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ── LEADERBOARD CARD ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════

  String get _lbActiveLabel {
    if (_lbSelectedMonth != null) {
      final parts = _lbSelectedMonth!.split('-');
      return '${_monthLabels[parts[1]] ?? ''} ${parts[0]}';
    }
    if (_lbSelectedYear != null) return _lbSelectedYear!;
    if (_lbPeriod == 'thismonth') return 'This Month';
    if (_lbPeriod == 'thisyear') return 'This Year';
    return 'All Time';
  }

  Widget _buildLeaderboardCard(
      bool isDark, Color textColor, Color text2) {
    final medals = ['🥇', '🥈', '🥉'];
    const teamColors = {
      'Red': AppColors.teamRed,
      'Yellow': AppColors.teamYellow,
      'Blue': AppColors.teamBlue,
    };
    final maxRev = _leaderboard.isNotEmpty
        ? (_leaderboard[0]['rev'] as double).clamp(1.0, double.infinity)
        : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration:
          _DS.glass(isDark: isDark, radius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withOpacity(0.06),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.06),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: _DS.yellowGrad,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.yellow.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text('🏆',
                              style: TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sales Leaderboard',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                  AppColors.yellow.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.yellow
                                          .withOpacity(0.25)),
                                ),
                                child: Text(
                                  _lbActiveLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.yellow,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_lbSelectedYear == null) ...[
                            _lbPeriodBtn('All', '', isDark),
                            const SizedBox(width: 6),
                            _lbPeriodBtn('This Month', 'thismonth', isDark),
                            const SizedBox(width: 6),
                            _lbPeriodBtn('This Year', 'thisyear', isDark),
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 22,
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.10),
                            ),
                            const SizedBox(width: 12),
                          ],

                          _lbYearDropdown(isDark, text2),

                          if (_lbSelectedYear != null) ...[
                            const SizedBox(width: 8),
                            _lbMonthDropdown(isDark, text2),
                          ],

                          if (_lbSelectedYear != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _lbSelectedYear = null;
                                  _lbSelectedMonth = null;
                                  _lbPeriod = '';
                                });
                                _reloadLeaderboard();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close_rounded,
                                        size: 11,
                                        color: Colors.red.shade400),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: _leaderboard
                      .take(5)
                      .toList()
                      .asMap()
                      .entries
                      .map((e) {
                    final i = e.key;
                    final s = e.value;
                    final rev = s['rev'] as double;
                    final pct = (rev / maxRev).clamp(0.0, 1.0);
                    final teamColor =
                        teamColors[s['team']] ?? text2;
                    final isTop3 = i < 3;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: isTop3
                                ? Text(medals[i],
                                style: const TextStyle(fontSize: 18))
                                : Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: text2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        s['name'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if ((s['team'] as String)
                                        .isNotEmpty) ...[
                                      const SizedBox(width: 7),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                          teamColor.withOpacity(0.12),
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s['team'] as String,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: teamColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.06),
                                    valueColor: AlwaysStoppedAnimation(
                                      isTop3 ? AppColors.accent : text2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ShaderMask(
                                shaderCallback: (b) =>
                                    _DS.greenGrad.createShader(b),
                                child: Text(
                                  '\$${_fmtAmt(rev)}',   // ← full number
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Text(
                                '${s['deals']} deal${(s['deals'] as int) != 1 ? 's' : ''}',
                                style:
                                TextStyle(fontSize: 11, color: text2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbPeriodBtn(String label, String val, bool isDark) {
    final isActive =
        _lbSelectedYear == null && _lbSelectedMonth == null && _lbPeriod == val;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() {
            _lbPeriod = val;
            _lbSelectedYear = null;
            _lbSelectedMonth = null;
          });
          await _reloadLeaderboard();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: isActive ? _DS.accentGrad : null,
            color: isActive
                ? null
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.accent
                  : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08)),
            ),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? Colors.white
                  : (isDark ? AppColors.darkText2 : AppColors.lightText2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbYearDropdown(bool isDark, Color text2) {
    final isActive = _lbSelectedYear != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.yellow.withOpacity(0.12)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.yellow.withOpacity(0.5)
                  : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _lbSelectedYear,
              hint: Text(
                'Year',
                style: TextStyle(
                  fontSize: 11,
                  color: text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? AppColors.yellow : text2,
              ),
              dropdownColor:
              isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.yellow
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              items: _lbYears
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _lbSelectedYear = val;
                  _lbSelectedMonth = null;
                  _lbPeriod = '';
                });
                _reloadLeaderboard();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _lbMonthDropdown(bool isDark, Color text2) {
    final isActive = _lbSelectedMonth != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.yellow.withOpacity(0.12)
                : (isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.yellow.withOpacity(0.5)
                  : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _lbSelectedMonth,
              hint: Text(
                'Month',
                style: TextStyle(
                  fontSize: 11,
                  color: text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive ? AppColors.yellow : text2,
              ),
              dropdownColor:
              isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.yellow
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              items: _monthsForYear(_lbSelectedYear!).map((m) {
                final parts = m.split('-');
                final label = _monthLabels[parts[1]] ?? parts[1];
                return DropdownMenuItem(value: m, child: Text(label));
              }).toList(),
              onChanged: (val) {
                setState(() => _lbSelectedMonth = val);
                _reloadLeaderboard();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Pipeline funnel ─────────────────────────────────────────────
  Widget _buildFunnelCard(bool isDark, Color textColor, Color text2) {
    final totalLeads = (_stats['totalLeads'] as int? ?? 0).toDouble();
    final totalDeals = (_stats['totalDeals'] as int? ?? 0).toDouble();
    final doneTasks = (_stats['tasksCompleted'] as int? ?? 0).toDouble();

    final stages = [
      _FunnelStage('Leads', totalLeads, AppColors.accent, _DS.accentGrad),
      _FunnelStage('Deals Closed', totalDeals, AppColors.accent2, _DS.purpleGrad),
      _FunnelStage('Tasks Done', doneTasks, AppColors.green, _DS.greenGrad),
    ];
    final maxVal =
    stages.fold(1.0, (m, s) => s.value > m ? s.value : m);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration:
          _DS.glass(isDark: isDark, radius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: _DS.purpleGrad,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent2.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.filter_alt_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pipeline Overview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        if (_activeFilter.isNotEmpty)
                          _filterBadgeSmall(_activeFilter),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stages.map((s) {
                  final pct = maxVal > 0 ? s.value / maxVal : 0.0;
                  final barH = (pct * 130).clamp(8.0, 130.0);
                  return Expanded(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              s.gradient.createShader(b),
                          child: Text(
                            s.value.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          height: barH,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                s.color.withOpacity(0.9),
                                s.color.withOpacity(0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)),
                            boxShadow: [
                              BoxShadow(
                                color: s.color.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: text2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _convRate(
                          'Lead → Deal',
                          totalLeads > 0
                              ? '${(totalDeals / totalLeads * 100).toStringAsFixed(0)}%'
                              : '0%',
                          _DS.accentGrad,
                          text2,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08),
                        ),
                        _convRate(
                          'Deal → Done',
                          totalDeals > 0
                              ? '${(doneTasks / totalDeals * 100).toStringAsFixed(0)}%'
                              : '0%',
                          _DS.greenGrad,
                          text2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _convRate(
      String label, String value, LinearGradient grad, Color text2) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => grad.createShader(b),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: text2),
        ),
      ],
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────
class _StatDef {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;
  _StatDef(this.label, this.value, this.icon, this.color, this.gradient,
      this.sub);
}

class _FunnelStage {
  final String label;
  final double value;
  final Color color;
  final LinearGradient gradient;
  _FunnelStage(this.label, this.value, this.color, this.gradient);
}

class _AmountDef {
  final String label;
  final String value;
  final String subtitle;
  final String emoji;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  const _AmountDef({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}