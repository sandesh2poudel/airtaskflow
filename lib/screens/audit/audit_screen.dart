// lib/screens/audit/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/sticky_table.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _svc        = FirestoreService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _logs     = [];
  bool   _loading     = true;
  String _searchQuery = '';

  // ── Period filter (mirrors UsersScreen) ──────────────────────
  int _filterYear  = DateTime.now().year;
  int _filterMonth = 0; // 0 = full year, 1–12 = month

  // ── Role / User filter ────────────────────────────────────────
  String _roleFilter = '';
  String _userFilter = '';

  static const _cols = [
    TableCol('Timestamp', 170),
    TableCol('User',      140),
    TableCol('Role',      110),
    TableCol('Action',    320),
    TableCol('Record ID', 160),
  ];

  static const _monthNames = [
    'All Months', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug',  'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _roles = ['superadmin', 'sales', 'teamleader', 'writer'];

  List<int> get _years =>
      List.generate(8, (i) => 2030 - i); // 2030 … 2023

  /// Sorted unique usernames found in the loaded logs
  List<String> get _distinctUsers {
    final seen = <String>{};
    for (final l in _logs) {
      final u = _s(l, 'user');
      if (u.isNotEmpty) seen.add(u);
    }
    return seen.toList()..sort();
  }

  /// Build the period prefix used for filtering, e.g. "2026" or "2026-05"
  String get _periodPrefix {
    final y = _filterYear.toString();
    if (_filterMonth == 0) return y;
    return '$y-${_filterMonth.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() =>
        setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _svc.getAuditLog(limit: 300);
      // Guard: keep only proper Map entries so JS undefined can't sneak in
      final logs = raw
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Safe field extractor — guards against JS `undefined` ──────
  static String _s(Map<String, dynamic> l, String key) {
    final v = l[key];
    if (v == null) return '';
    try { return v.toString(); } catch (_) { return ''; }
  }

  // ── Filtered view of logs ─────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    return _logs.where((l) {
      // Period filter — match on the ISO timestamp string
      final time = _s(l, 'time');
      if (!time.startsWith(_periodPrefix)) return false;

      // Role filter
      if (_roleFilter.isNotEmpty && _s(l, 'role') != _roleFilter) {
        return false;
      }

      // User filter
      if (_userFilter.isNotEmpty && _s(l, 'user') != _userFilter) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final hay =
        '${_s(l, 'user')} ${_s(l, 'role')} ${_s(l, 'action')} ${_s(l, 'record')}'
            .toLowerCase();
        if (!hay.contains(_searchQuery)) return false;
      }

      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2    : AppColors.lightText2;

    final width        = MediaQuery.of(context).size.width;
    final isMobile     = width < 600;
    final filtered     = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────
        _buildHeader(isDark, bg, surface, border, textColor, text2, isMobile),

        // ── Period filter bar ────────────────────────────────────
        _buildPeriodBar(isDark, bg, surface, border, textColor, text2),

        // ── Search + role filter bar ─────────────────────────────
        _buildSearchBar(isDark, bg, surface, border, textColor, text2, filtered),

        // ── Table / cards ────────────────────────────────────────
        Expanded(
          child: isMobile
              ? _buildMobileCards(filtered, isDark, surface, border, textColor, text2)
              : _buildTable(filtered, isDark, surface, border, textColor, text2),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, Color bg, Color surface, Color border,
      Color textColor, Color text2, bool isMobile) {
    final iconBox = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.accent2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [BoxShadow(
          color: AppColors.accent.withOpacity(0.28),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Audit Log',
            style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: textColor)),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.22)),
            ),
            child: Text('${_logs.length} entries',
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            Text('All system actions with timestamps',
                style: TextStyle(fontSize: 12, color: text2)),
          ],
        ]),
      ],
    );

    final refreshBtn = Tooltip(
      message: 'Refresh',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _load,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.refresh_rounded, size: 15, color: AppColors.accent),
              if (!isMobile) ...[
                const SizedBox(width: 6),
                const Text('Refresh',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
              ],
            ]),
          ),
        ),
      ),
    );

    if (isMobile) {
      return Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            iconBox,
            const SizedBox(width: 12),
            Expanded(child: titleBlock),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [refreshBtn]),
        ]),
      );
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        iconBox,
        const SizedBox(width: 14),
        Expanded(child: titleBlock),
        refreshBtn,
      ]),
    );
  }

  // ── Period filter bar (year + month dropdowns) ────────────────
  Widget _buildPeriodBar(bool isDark, Color bg, Color surface, Color border,
      Color textColor, Color text2) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Label
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_outlined, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('Filter Period:',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: text2)),
          ]),

          // Year dropdown
          _dropdownBox(
            surface: surface,
            border: border,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _filterYear,
                isDense: true,
                dropdownColor: surface,
                items: _years
                    .map((y) => DropdownMenuItem<int>(
                  value: y,
                  child: Text('$y',
                      style: TextStyle(fontSize: 12, color: textColor)),
                ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _filterYear = v ?? DateTime.now().year),
              ),
            ),
          ),

          // Month dropdown
          _dropdownBox(
            surface: surface,
            border: border,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _filterMonth,
                isDense: true,
                dropdownColor: surface,
                items: List.generate(
                  13,
                      (i) => DropdownMenuItem<int>(
                    value: i,
                    child: Text(_monthNames[i],
                        style: TextStyle(fontSize: 12, color: textColor)),
                  ),
                ),
                onChanged: (v) => setState(() => _filterMonth = v ?? 0),
              ),
            ),
          ),

          // Active period badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withOpacity(0.30)),
            ),
            child: Text(
              _filterMonth == 0
                  ? 'Year: $_filterYear'
                  : '${_monthNames[_filterMonth]} $_filterYear',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search + role filter bar ──────────────────────────────────
  Widget _buildSearchBar(
      bool isDark,
      Color bg,
      Color surface,
      Color border,
      Color textColor,
      Color text2,
      List<Map<String, dynamic>> filtered) {
    final hasFilter = _roleFilter.isNotEmpty || _userFilter.isNotEmpty || _searchCtrl.text.isNotEmpty;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search field
          SizedBox(
            width: 260, height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search by user, action, record…',
                hintStyle: TextStyle(color: text2, fontSize: 12.5),
                filled: true, fillColor: surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5)),
                prefixIcon: Icon(Icons.search, size: 16, color: text2),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // Role dropdown
          _dropdownBox(
            surface: surface,
            border: border,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _roleFilter.isEmpty ? null : _roleFilter,
                hint: Text('All Roles',
                    style: TextStyle(fontSize: 12, color: text2)),
                isDense: true,
                dropdownColor: surface,
                style: TextStyle(fontSize: 12, color: textColor),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('All Roles',
                        style: TextStyle(fontSize: 12, color: textColor)),
                  ),
                  ..._roles.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r,
                        style: TextStyle(fontSize: 12, color: textColor)),
                  )),
                ],
                onChanged: (v) => setState(() => _roleFilter = v ?? ''),
              ),
            ),
          ),

          // User dropdown
          _dropdownBox(
            surface: surface,
            border: border,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _userFilter.isEmpty ? null : _userFilter,
                hint: Text('All Users',
                    style: TextStyle(fontSize: 12, color: text2)),
                isDense: true,
                dropdownColor: surface,
                style: TextStyle(fontSize: 12, color: textColor),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('All Users',
                        style: TextStyle(fontSize: 12, color: textColor)),
                  ),
                  ..._distinctUsers.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u,
                        style: TextStyle(fontSize: 12, color: textColor)),
                  )),
                ],
                onChanged: (v) => setState(() => _userFilter = v ?? ''),
              ),
            ),
          ),

          // Clear filters
          if (hasFilter)
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                setState(() { _roleFilter = ''; _userFilter = ''; });
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Text('Clear Filters',
                    style: TextStyle(fontSize: 12, color: text2)),
              ),
            ),

          // Result count badge
          if (filtered.length != _logs.length)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${filtered.length} of ${_logs.length}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // ── Desktop table ─────────────────────────────────────────────
  Widget _buildTable(List<Map<String, dynamic>> logs, bool isDark,
      Color surface, Color border, Color textColor, Color text2) {
    final roleColors = _roleColorMap(text2);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.accent))
          : StickyTable(
        columns: _cols,
        isDark: isDark,
        emptyMessage: 'No audit entries found',
        emptySubMessage:
        'Try adjusting your filters or period selection',
        emptyIcon: Icons.history_rounded,
        rows: logs.map((l) => _buildRow(l, roleColors, textColor, text2)).toList(),
      ),
    );
  }

  // ── Mobile cards ──────────────────────────────────────────────
  Widget _buildMobileCards(List<Map<String, dynamic>> logs, bool isDark,
      Color surface, Color border, Color textColor, Color text2) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (logs.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 52, color: text2),
              const SizedBox(height: 12),
              Text('No audit entries found',
                  style: TextStyle(
                      fontSize: 15,
                      color: text2,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('Try adjusting filters or period',
                  style: TextStyle(fontSize: 12, color: text2)),
            ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final l = logs[i];
        return _AuditCard(
          log: l,
          isDark: isDark,
          surface: surface,
          border: border,
          textColor: textColor,
          text2: text2,
          roleColors: _roleColorMap(text2),
        );
      },
    );
  }

  // ── Row builder (shared for table) ───────────────────────────
  List<Widget> _buildRow(Map<String, dynamic> l,
      Map<String, Color> roleColors, Color textColor, Color text2) {
    final role      = _s(l, 'role');
    final roleColor = roleColors[role] ?? text2;
    final timeRaw   = _s(l, 'time');
    final timeDisplay = timeRaw.length >= 19
        ? timeRaw.substring(0, 19).replaceAll('T', '  ')
        : timeRaw;

    return [
      // Timestamp
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(timeDisplay,
            style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: AppColors.darkText3)),
      ),
      // User
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(_s(l, 'user'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor)),
      ),
      // Role chip
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: roleColor.withOpacity(0.3)),
          ),
          child: Text(role,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: roleColor)),
        ),
      ),
      // Action
      tCell(_s(l, 'action'), color: text2, fontSize: 12.5),
      // Record ID
      tCell(_s(l, 'record'), color: AppColors.accent, fontSize: 11, mono: true),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────
  Map<String, Color> _roleColorMap(Color text2) => {
    'superadmin': AppColors.purple,
    'sales':      AppColors.accent,
    'teamleader': AppColors.yellow,
    'writer':     AppColors.green,
  };

  Widget _dropdownBox({required Color surface, required Color border, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOBILE AUDIT CARD
// ══════════════════════════════════════════════════════════════════════════════
class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final bool isDark;
  final Color surface, border, textColor, text2;
  final Map<String, Color> roleColors;

  const _AuditCard({
    required this.log,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.roleColors,
  });

  @override
  Widget build(BuildContext context) {
    String safeField(String key) {
      final v = log[key];
      if (v == null) return '';
      try { return v.toString(); } catch (_) { return ''; }
    }

    final role       = safeField('role');
    final roleColor  = roleColors[role] ?? text2;
    final timeRaw    = safeField('time');
    final timeDisplay = timeRaw.length >= 19
        ? timeRaw.substring(0, 19).replaceAll('T', ' ')
        : timeRaw;
    final user    = safeField('user');
    final action  = safeField('action');
    final record  = safeField('record');

    // Initials from username
    final initials = user.split(RegExp(r'[\s._@]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: roleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar + user + role chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [roleColor, roleColor.withOpacity(0.55)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(
                          color: roleColor.withOpacity(0.25),
                          blurRadius: 5, offset: const Offset(0, 2),
                        )],
                      ),
                      child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                          const SizedBox(height: 3),
                          // Role chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                              border:
                              Border.all(color: roleColor.withOpacity(0.3)),
                            ),
                            child: Text(role,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: roleColor)),
                          ),
                        ],
                      ),
                    ),
                    // Timestamp badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timeDisplay.length > 10
                            ? timeDisplay.substring(0, 10)
                            : timeDisplay,
                        style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: text2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder),
                const SizedBox(height: 10),

                // Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          size: 13, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(action,
                          style: TextStyle(fontSize: 12.5, color: text2)),
                    ),
                  ],
                ),

                if (record.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.tag_rounded,
                          size: 12, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(record,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.accent),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],

                // Full timestamp at the bottom
                const SizedBox(height: 8),
                Text(timeDisplay,
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: text2.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}