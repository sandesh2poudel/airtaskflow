// lib/screens/users/users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/export_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/sticky_table.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _svc    = FirestoreService();
  final _export = ExportService();

  List<UserModel> _users    = [];
  List<UserModel> _filtered = [];
  bool   _loading   = true;
  String _exporting = '';

  final _searchCtrl = TextEditingController();
  String _roleFilter = '';
  String _teamFilter = '';

  // ── Export month/year filter ──────────────────────────────────
  // '' = all time, 'YYYY' = year, 'YYYY-MM' = month
  int    _exportYear  = DateTime.now().year;
  int    _exportMonth = 0; // 0 = full year, 1-12 = specific month

  static const double _kMobileHeader = 540;
  static const double _kMobileCards  = 600;

  static const _cols = [
    TableCol('#',        45),
    TableCol('User ID',  148),
    TableCol('Name',     168),
    TableCol('Username', 148),
    TableCol('Role',     130),
    TableCol('Team',     116),
    TableCol('Actions',  300),
  ];

  // Years to show in picker (current year back to 2023)
  List<int> get _years {
    return List.generate(5, (i) => 2030 - i); // 2030, 2029, 2028, 2027, 2026
  }

  // Build the filter string passed to ExportService
  String get _exportFilter {
    final y = _exportYear.toString();
    if (_exportMonth == 0) return y;
    final m = _exportMonth.toString().padLeft(2, '0');
    return '$y-$m';
  }



  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _svc.getAllUsers();
      if (mounted) {
        setState(() { _users = users; _loading = false; });
        _applyFilter();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchQ = q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.userId.toLowerCase().contains(q);
        final matchR = _roleFilter.isEmpty || u.role == _roleFilter;
        final matchT = _teamFilter.isEmpty || u.team == _teamFilter;
        return matchQ && matchR && matchT;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2    : AppColors.lightText2;
    final width     = MediaQuery.of(context).size.width;
    final isMobileCards = width < _kMobileCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, isDark, bg, textColor, text2),
        _buildExportFilterBar(isDark, bg, surface, border, textColor, text2),
        _buildFilterBar(bg, surface, border, textColor, text2),
        Expanded(
          child: isMobileCards
              ? _buildMobileCards(isDark, surface, border, textColor, text2)
              : Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              )],
            ),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : StickyTable(
              columns: _cols,
              isDark: isDark,
              emptyMessage: 'No users found',
              emptySubMessage: _searchCtrl.text.isNotEmpty ||
                  _roleFilter.isNotEmpty || _teamFilter.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Click "Add User" to create the first user',
              emptyIcon: Icons.group_outlined,
              rows: _tableRows(textColor, text2),
            ),
          ),
        ),
      ],
    );
  }

  // ── Export Period Filter Bar ──────────────────────────────────
  Widget _buildExportFilterBar(bool isDark, Color bg, Color surface,
      Color border, Color textColor, Color text2) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_alt_outlined, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              'Export Period:',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: text2),
            ),
          ]),

          // Year dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _exportYear,
                isDense: true,
                dropdownColor: surface,
                items: _years
                    .map((y) => DropdownMenuItem<int>(
                  value: y,
                  child: Text('$y',
                      style: TextStyle(
                          fontSize: 12, color: textColor)),
                ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _exportYear = v ?? DateTime.now().year),
              ),
            ),
          ),

          // Month dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _exportMonth,
                isDense: true,
                dropdownColor: surface,
                items: List.generate(
                  13,
                      (i) => DropdownMenuItem<int>(
                    value: i,
                    child: Text(_monthNames[i],
                        style:
                        TextStyle(fontSize: 12, color: textColor)),
                  ),
                ),
                onChanged: (v) =>
                    setState(() => _exportMonth = v ?? 0),
              ),
            ),
          ),

          // Active period badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border:
              Border.all(color: AppColors.accent.withOpacity(0.30)),
            ),
            child: Text(
              _exportMonth == 0
                  ? 'Year: $_exportYear'
                  : '${_monthNames[_exportMonth]} $_exportYear',
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

  // ── Table rows ────────────────────────────────────────────────
  List<List<Widget>> _tableRows(Color textColor, Color text2) {
    return _filtered.asMap().entries.map((e) {
      final i = e.key;
      final u = e.value;
      return <Widget>[
        tCell('${i + 1}', color: text2, fontSize: 11),
        tCell(
          u.userId.length > 13 ? '${u.userId.substring(0, 13)}…' : u.userId,
          color: text2, fontSize: 10.5, mono: true,
        ),
        _nameCell(u, textColor),
        tCell('@${u.username}', color: text2, fontSize: 12, mono: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: _RoleBadge(role: u.role),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: _TeamBadge(team: u.team, text2: text2),
        ),
        tActions(_actionButtons(u)),
      ];
    }).toList();
  }

  List<Widget> _actionButtons(UserModel u) => [
    tAction('Edit', AppColors.accent, () => _openUserForm(context, u),
        icon: Icons.edit_outlined),
    tAction('Delete', AppColors.red, () => _confirmDelete(context, u),
        icon: Icons.delete_outline),
    if (u.isSales) ...[
      tAction('Leads', AppColors.accent,
              () => _exportUser(context, u, 'leads'),
          icon: Icons.download_outlined),
      tAction('Deals', AppColors.green,
              () => _exportUser(context, u, 'deals'),
          icon: Icons.download_outlined),
    ],
    if (u.isWriter)
      tAction('Tasks', AppColors.purple,
              () => _exportUser(context, u, 'tasks'),
          icon: Icons.download_outlined),
  ];

  // ── Mobile Cards ──────────────────────────────────────────────
  Widget _buildMobileCards(bool isDark, Color surface, Color border,
      Color textColor, Color text2) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.group_outlined, size: 52, color: text2),
          const SizedBox(height: 12),
          Text('No users found',
              style: TextStyle(fontSize: 15, color: text2,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            _searchCtrl.text.isNotEmpty ||
                _roleFilter.isNotEmpty || _teamFilter.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Tap "Add User" to create the first user',
            style: TextStyle(fontSize: 12, color: text2),
          ),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        final u = _filtered[i];
        return _UserCard(
          index: i + 1,
          user: u,
          isDark: isDark,
          surface: surface,
          border: border,
          textColor: textColor,
          text2: text2,
          actionButtons: _actionButtons(u),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext ctx, bool isDark, Color bg,
      Color textColor, Color text2) {
    final screenWidth = MediaQuery.of(ctx).size.width;
    final isMobile    = screenWidth < _kMobileHeader;

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
      child: const Icon(Icons.group_outlined, color: Colors.white, size: 20),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User Management',
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
            child: Text('${_users.length} users',
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            Text('Add and manage system users',
                style: TextStyle(fontSize: 12, color: text2)),
          ],
        ]),
      ],
    );

    final themeToggle = Consumer<ThemeProvider>(
      builder: (context, theme, _) => Tooltip(
        message: theme.isDark ? 'Light mode' : 'Dark mode',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => theme.toggleTheme(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Icon(
                theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 17,
                color: text2,
              ),
            ),
          ),
        ),
      ),
    );

    final refreshBtn = Tooltip(
      message: 'Refresh',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _load,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
            ),
            child: const Icon(Icons.refresh_rounded,
                size: 17, color: AppColors.accent),
          ),
        ),
      ),
    );

    final exportBtn = _ExportAllButton(
      export: _export,
      exporting: _exporting == 'all',
      isDark: isDark,
      compact: isMobile,
      exportFilter: _exportFilter,
      onStart: () => setState(() => _exporting = 'all'),
      onDone: (ok, msg) {
        if (mounted) {
          setState(() => _exporting = '');
          _showSnack(msg, ok ? AppColors.green : AppColors.red);
        }
      },
    );

    final addUserBtn = ElevatedButton.icon(
      onPressed: () => _openUserForm(ctx, null),
      icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.white),
      label: Text(
        isMobile ? 'Add' : 'Add User',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );

    if (isMobile) {
      return Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(child: titleBlock),
            ]),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                themeToggle,
                const SizedBox(width: 8),
                refreshBtn,
                const SizedBox(width: 8),
                exportBtn,
                const SizedBox(width: 8),
                addUserBtn,
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        iconBox,
        const SizedBox(width: 14),
        Expanded(child: titleBlock),
        themeToggle,
        const SizedBox(width: 8),
        refreshBtn,
        const SizedBox(width: 8),
        exportBtn,
        const SizedBox(width: 8),
        addUserBtn,
      ]),
    );
  }

  // ── User search/role/team filter bar (unchanged) ──────────────
  Widget _buildFilterBar(Color bg, Color surface, Color border,
      Color textColor, Color text2) {
    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260, height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search name, username, ID…',
                hintStyle: TextStyle(color: text2, fontSize: 12.5),
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5)),
                prefixIcon: Icon(Icons.search, size: 16, color: text2),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          _filterDropdown(
            value: _roleFilter.isEmpty ? null : _roleFilter,
            hint: 'All Roles',
            items: const ['sales', 'teamleader', 'writer', 'superadmin'],
            surface: surface, border: border, tc: textColor, t2: text2,
            onChanged: (v) { setState(() => _roleFilter = v ?? ''); _applyFilter(); },
          ),
          _filterDropdown(
            value: _teamFilter.isEmpty ? null : _teamFilter,
            hint: 'All Teams',
            items: AppConstants.teams,
            surface: surface, border: border, tc: textColor, t2: text2,
            onChanged: (v) { setState(() => _teamFilter = v ?? ''); _applyFilter(); },
          ),
          if (_roleFilter.isNotEmpty || _teamFilter.isNotEmpty ||
              _searchCtrl.text.isNotEmpty)
            InkWell(
              onTap: () {
                _searchCtrl.clear();
                setState(() { _roleFilter = ''; _teamFilter = ''; });
                _applyFilter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Text('Clear Filters',
                    style: TextStyle(fontSize: 12, color: text2)),
              ),
            ),
          if (_filtered.length != _users.length)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_filtered.length} of ${_users.length}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.accent,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Color surface,
    required Color border,
    required Color tc,
    required Color t2,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 12, color: t2)),
          isDense: true,
          dropdownColor: surface,
          style: TextStyle(fontSize: 12, color: tc),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(hint, style: TextStyle(fontSize: 12, color: tc)),
            ),
            ...items.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: TextStyle(fontSize: 12, color: tc)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _nameCell(UserModel u, Color textColor) {
    const roleColors = {
      'superadmin': AppColors.purple,
      'sales':      AppColors.accent,
      'teamleader': AppColors.yellow,
      'writer':     AppColors.green,
    };
    final color = roleColors[u.role] ?? AppColors.accent;
    final initials = u.name.split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.55)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 5, offset: const Offset(0, 2),
            )],
          ),
          child: Center(child: Text(initials,
              style: const TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(u.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: textColor))),
      ]),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _exportUser(BuildContext context, UserModel u, String type) async {
    final key = '$type${u.userId}';
    setState(() => _exporting = key);
    try {
      if (type == 'leads') {
        await _export.exportUserLeads(u, filter: _exportFilter);
      } else if (type == 'deals') {
        await _export.exportUserDeals(u, filter: _exportFilter);
      } else if (type == 'tasks') {
        await _export.exportWriterTasks(u, filter: _exportFilter);
      }
      final periodLabel = _exportMonth == 0
          ? '$_exportYear'
          : '${_monthNames[_exportMonth]} $_exportYear';
      if (mounted) {
        _showSnack(
            '✅ ${u.name} $type exported ($periodLabel)!',
            AppColors.green);
      }
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', AppColors.red);
    }
    if (mounted) setState(() => _exporting = '');
  }

  void _openUserForm(BuildContext context, UserModel? user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserDialog(user: user, svc: _svc, onDone: _load),
    );
  }

  void _confirmDelete(BuildContext context, UserModel u) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove User?'),
        content: Text('Remove "${u.name}" (@${u.username})?\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.deleteUser(u.userId);
              await _load();
              if (context.mounted) _showSnack('${u.name} removed.', AppColors.red);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, elevation: 0),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
  static const _monthNames = [
    'All Months', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// MOBILE USER CARD  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _UserCard extends StatelessWidget {
  final int index;
  final UserModel user;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color textColor;
  final Color text2;
  final List<Widget> actionButtons;

  const _UserCard({
    required this.index,
    required this.user,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.actionButtons,
  });

  static const _roleColors = {
    'superadmin': AppColors.purple,
    'sales':      AppColors.accent,
    'teamleader': AppColors.yellow,
    'writer':     AppColors.green,
  };

  @override
  Widget build(BuildContext context) {
    final color = _roleColors[user.role] ?? AppColors.accent;
    final initials = user.name.split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.55)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(
                          color: color.withOpacity(0.25),
                          blurRadius: 6, offset: const Offset(0, 2),
                        )],
                      ),
                      child: Center(child: Text(initials,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 2),
                          Text('@${user.username}',
                              style: TextStyle(fontSize: 12, color: text2,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text('$index',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: text2))),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _RoleBadge(role: user.role),
                  if (user.team.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TeamBadge(team: user.team, text2: text2),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.userId.length > 10
                          ? '${user.userId.substring(0, 10)}…'
                          : user.userId,
                      style: TextStyle(fontSize: 9.5, color: text2,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Divider(height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: actionButtons),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ROLE BADGE  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  static const _map = {
    'superadmin': (AppColors.purple, Icons.shield_outlined),
    'sales':      (AppColors.accent, Icons.trending_up_rounded),
    'teamleader': (AppColors.yellow, Icons.star_outline_rounded),
    'writer':     (AppColors.green,  Icons.edit_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _map[role] ?? (AppColors.accent, Icons.person_outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(role, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TEAM BADGE  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _TeamBadge extends StatelessWidget {
  final String team;
  final Color text2;
  const _TeamBadge({required this.team, required this.text2});

  static final _colors = {
    'Red':    AppColors.teamRed,
    'Yellow': AppColors.teamYellow,
    'Blue':   AppColors.teamBlue,
    'Pink':   AppColors.teamPink,
  };

  @override
  Widget build(BuildContext context) {
    if (team.isEmpty) return Text('—', style: TextStyle(color: text2, fontSize: 13));
    final color = _colors[team] ?? text2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(team, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPORT ALL BUTTON  (now receives exportFilter)
// ══════════════════════════════════════════════════════════════════════════════
class _ExportAllButton extends StatelessWidget {
  final ExportService export;
  final bool exporting;
  final bool isDark;
  final bool compact;
  final String exportFilter;
  final VoidCallback onStart;
  final void Function(bool ok, String msg) onDone;

  const _ExportAllButton({
    required this.export,
    required this.exporting,
    required this.isDark,
    required this.exportFilter,
    required this.onStart,
    required this.onDone,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Export All Data',
      color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 44),
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12, vertical: compact ? 8 : 9),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.green.withOpacity(0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          exporting
              ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.green))
              : const Icon(Icons.download_outlined,
              size: 14, color: AppColors.green),
          if (!compact) ...[
            const SizedBox(width: 6),
            const Text('Export All',
                style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w700, color: AppColors.green)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: AppColors.green),
          ],
        ]),
      ),
      itemBuilder: (_) => [
        _item('leads', Icons.fact_check_outlined,  AppColors.accent, 'Export All Leads (Excel)'),
        _item('deals', Icons.attach_money,         AppColors.green,  'Export All Deals (Excel)'),
        _item('tasks', Icons.task_outlined,        AppColors.purple, 'Export All Tasks (Excel)'),
      ],
      onSelected: (val) async {
        onStart();
        try {
          if (val == 'leads') {
            await export.exportAllLeads(filter: exportFilter);
          } else if (val == 'deals') {
            await export.exportAllDeals(filter: exportFilter);
          } else if (val == 'tasks') {
            await export.exportAllTasks(filter: exportFilter);
          }
          onDone(true, '✅ Exported ${val}s to Excel!');
        } catch (e) {
          onDone(false, 'Export failed: $e');
        }
      },
    );
  }

  PopupMenuItem<String> _item(
      String val, IconData icon, Color color, String label) {
    return PopupMenuItem(
      value: val, height: 40,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// USER FORM DIALOG  (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _UserDialog extends StatefulWidget {
  final UserModel? user;
  final FirestoreService svc;
  final VoidCallback onDone;
  const _UserDialog(
      {required this.user, required this.svc, required this.onDone});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'sales', _team = '';
  bool _saving = false, _obscure = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      final u = widget.user!;
      _nameCtrl.text = u.name;
      _userCtrl.text = u.username;
      _role = u.role;
      _team = u.team;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _userCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and username are required');
      return;
    }
    if (widget.user == null && _passCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Password is required for new users');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      if (widget.user == null) {
        await widget.svc.addUser(UserModel(
          userId: '', name: _nameCtrl.text.trim(),
          username: _userCtrl.text.trim().toLowerCase(),
          role: _role, team: _team, password: _passCtrl.text.trim(),
        ));
      } else {
        final data = <String, dynamic>{
          'name': _nameCtrl.text.trim(),
          'username': _userCtrl.text.trim().toLowerCase(),
          'role': _role, 'team': _team,
        };
        if (_passCtrl.text.trim().isNotEmpty) {
          data['password'] = _passCtrl.text.trim();
        }
        await widget.svc.updateUser(widget.user!.userId, data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.user == null
              ? '✅ User added!' : '✅ User updated!'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final surface2  = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final textColor = isDark ? AppColors.darkText      : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2     : AppColors.lightText2;
    final isEdit    = widget.user != null;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 580),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accent2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                    isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'Edit User' : 'Add New User',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w700, color: textColor)),
                Text(
                    isEdit
                        ? 'Update user information'
                        : 'Fill in the details to create a user',
                    style: TextStyle(fontSize: 11, color: text2)),
              ]),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.red.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.red.withOpacity(0.28)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: AppColors.red),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.red))),
                        ]),
                      ),
                    ],
                    Wrap(spacing: 16, runSpacing: 16, children: [
                      _field('Full Name *', _nameCtrl, textColor, text2,
                          hint: 'John Smith',
                          icon: Icons.person_outline, w: 240),
                      _field('Username *', _userCtrl, textColor, text2,
                          hint: 'jsmith',
                          icon: Icons.alternate_email_rounded, w: 200),
                      _passField(textColor, text2, isEdit),
                      _dropdown('Role *', _role,
                          ['sales', 'teamleader', 'writer', 'superadmin'],
                          ['Sales Person', 'Team Leader', 'Writer', 'Super Admin'],
                          textColor, text2, surface2,
                              (v) => setState(() => _role = v!), w: 180),
                      _dropdown('Team', _team,
                          ['', ...AppConstants.teams],
                          ['No Team',
                            ...AppConstants.teams.map((t) => '$t Team')],
                          textColor, text2, surface2,
                              (v) => setState(() => _team = v ?? ''), w: 160),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.18)),
                      ),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.accent),
                            SizedBox(width: 8),
                            Expanded(child: Text(
                              'Login uses username + password stored in Firestore. '
                                  'No Firebase Auth needed. The user can log in '
                                  'immediately after being created.',
                              style: TextStyle(fontSize: 11,
                                  color: AppColors.accent, height: 1.5),
                            )),
                          ]),
                    ),
                  ]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Update User' : 'Add User',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      Color tc, Color t2,
      {String? hint, IconData? icon, double w = 180}) {
    return SizedBox(
      width: w,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: t2)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 13, color: tc),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: t2),
            prefixIcon: icon != null
                ? Icon(icon, size: 15, color: AppColors.accent)
                : null,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _passField(Color tc, Color t2, bool isEdit) {
    return SizedBox(
      width: 210,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isEdit ? 'New Password (blank = keep)' : 'Password *',
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: t2)),
        const SizedBox(height: 5),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: TextStyle(fontSize: 13, color: tc),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(fontSize: 12.5, color: t2),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 15, color: AppColors.accent),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16, color: t2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _dropdown(String label, String value,
      List<String> values, List<String> labels,
      Color tc, Color t2, Color surface2,
      ValueChanged<String?> onChange, {double w = 180}) {
    return SizedBox(
      width: w,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w600, color: t2)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: values.contains(value) ? value : values.first,
          dropdownColor: surface2,
          style: TextStyle(fontSize: 13, color: tc),
          items: List.generate(
            values.length,
                (i) => DropdownMenuItem(
              value: values[i],
              child: Text(labels[i],
                  style: TextStyle(fontSize: 13, color: tc)),
            ),
          ),
          onChanged: onChange,
          decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10)),
        ),
      ]),
    );
  }
}