// lib/screens/deals/deals_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/deal_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/sticky_table.dart';
import '../../widgets/status_badge.dart';

class DealsScreen extends StatefulWidget {
  const DealsScreen({super.key});
  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  final _svc        = FirestoreService();
  final _searchCtrl = TextEditingController();

  String _searchQuery   = '';
  String _filterMonth   = _currentMonthKey();
  String _filterSalesId = 'all';

  static String _currentMonthKey() {
    final now = DateTime.now();
    final m   = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  List<UserModel> _salesUsers = [];

  bool              _groupByStatus = true;
  final Set<String> _collapsed     = {};

  String _quickDate = '';

  Stream<List<DealModel>>? _dealsStream;
  bool _streamInitialized = false;

  static const _colsAdmin = [
    TableCol('Task ID',        130),
    TableCol('Sales Person',   140),
    TableCol('Date',           100),
    TableCol('Client',         140),
    TableCol('Words',           80),
    TableCol('Total(AUD)',     115),
    TableCol('1st Pay',         95),
    TableCol('2nd Pay',         95),
    TableCol('Pay Status',     115),
    TableCol('Assign',         105),
    TableCol('Writer',         120),
    TableCol('Notes',          150),
    TableCol('Task File',      100),
    TableCol('Pay Screenshot', 130),
    TableCol('Actions',        160),
  ];

  static const _colsOther = [
    TableCol('Task ID',        130),
    TableCol('Date',           100),
    TableCol('Client',         145),
    TableCol('Words',           80),
    TableCol('Total(AUD)',     115),
    TableCol('1st Pay',         95),
    TableCol('2nd Pay',         95),
    TableCol('Pay Status',     115),
    TableCol('Assign',         105),
    TableCol('Writer',         120),
    TableCol('Notes',          150),
    TableCol('Task File',      100),
    TableCol('Pay Screenshot', 130),
    TableCol('Actions',        160),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      _streamInitialized = true;
      final user = context.read<AuthProvider>().currentUser!;
      _dealsStream = _svc.dealsStream(user);
      _loadSalesUsers(user);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadSalesUsers(UserModel user) async {
    if (!user.isAdmin) return;
    final all = await _svc.getAllUsers();
    if (mounted) {
      setState(() {
        _salesUsers = all.where((u) => u.isSales).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesQuickDate(String dealDate) {
    if (_quickDate.isEmpty) return true;
    final now = DateTime.now();
    DateTime? d;
    try { d = DateTime.parse(dealDate); } catch (_) { return false; }
    switch (_quickDate) {
      case 'today':
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case 'week':
        final ws = now.subtract(Duration(days: now.weekday - 1));
        final we = ws.add(const Duration(days: 6));
        return !d.isBefore(DateTime(ws.year, ws.month, ws.day)) &&
            !d.isAfter(DateTime(we.year, we.month, we.day, 23, 59));
      case 'month':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  bool get _hasActiveFilters =>
      _filterMonth != _currentMonthKey() ||
          _filterSalesId != 'all'        ||
          _quickDate.isNotEmpty          ||
          _searchQuery.isNotEmpty;

  void _clearAllFilters() => setState(() {
    _filterMonth   = _currentMonthKey();
    _filterSalesId = 'all';
    _quickDate     = '';
    _searchQuery   = '';
    _searchCtrl.clear();
  });

  String _quickDateLabel(String key) {
    switch (key) {
      case 'today': return 'Today';
      case 'week':  return 'This Week';
      case 'month': return 'This Month';
      default:      return '';
    }
  }

  List<DealModel> _applyFilters(List<DealModel> deals, UserModel user) {
    var filtered = deals;
    if (user.isAdmin && _filterSalesId != 'all') {
      filtered = filtered.where((d) => d.salesId == _filterSalesId).toList();
    }
    if (_quickDate.isNotEmpty) {
      filtered = filtered.where((d) => _matchesQuickDate(d.date)).toList();
    } else if (_filterMonth.isNotEmpty) {
      filtered = filtered.where((d) => d.date.startsWith(_filterMonth)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((d) =>
          '${d.salesName} ${d.clientName} ${d.taskCode} '
              '${d.paymentStatus} ${d.writerAssigned}'
              .toLowerCase()
              .contains(_searchQuery)).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final user      = context.watch<AuthProvider>().currentUser!;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2    : AppColors.lightText2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ──────────────────────────────────────────────
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Title block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Deals Closed',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor)),
                    if (_filterMonth.isNotEmpty || _quickDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        _quickDate.isNotEmpty
                            ? '· ${_quickDateLabel(_quickDate)}'
                            : '· $_filterMonth',
                        style: TextStyle(
                            fontSize: 13,
                            color: text2,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ]),
                  Text('Manage closed deals and payments',
                      style: TextStyle(fontSize: 12, color: text2)),
                ],
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerChip(
                    icon: Icons.table_rows_outlined,
                    label: 'Group by status',
                    active: _groupByStatus,
                    surface: surface,
                    border: border,
                    text2: text2,
                    onTap: () =>
                        setState(() => _groupByStatus = !_groupByStatus),
                  ),
                  const SizedBox(width: 8),
                  if (user.isSales || user.isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _openDealForm(context, user, null),
                      icon: const Icon(Icons.add,
                          size: 16, color: Colors.white),
                      label: const Text('Add Deal',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10)),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── ROW 2 — Summary pills (filtered) — matches screenshot style ══
        StreamBuilder<List<DealModel>>(
          stream: _dealsStream,
          builder: (ctx, snap) {
            if (_dealsStream == null) return const SizedBox.shrink();
            final all      = snap.data ?? [];
            final filtered = _applyFilters(all, user);
            return _DealSummaryBar(deals: filtered, bg: bg, text2: text2);
          },
        ),

        // ── ROW 3 — Search ════════════════════════════════════════
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: _searchDeco(text2, surface, border),
            ),
          ),
        ),

        // ── ROW 4 — Quick date chips + dropdowns ══════════════════
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _quickChip('Today',      'today', surface, border, text2),
              _quickChip('This Week',  'week',  surface, border, text2),
              _quickChip('This Month', 'month', surface, border, text2),
              _monthPicker(surface, border, textColor, text2),
              if (user.isAdmin && _salesUsers.isNotEmpty)
                _salesPersonPicker(surface, border, textColor, text2),
              if (_filterMonth != _currentMonthKey() &&
                  _filterMonth.isNotEmpty)
                _clearChipBtn('✕ Month',
                        () => setState(
                            () => _filterMonth = _currentMonthKey()),
                    surface, border, text2),
              if (user.isAdmin && _filterSalesId != 'all')
                _clearChipBtn('✕ Show All',
                        () => setState(() => _filterSalesId = 'all'),
                    surface, border, text2),
              if (_hasActiveFilters)
                _clearChipBtn('Clear All', _clearAllFilters,
                    AppColors.accent.withOpacity(0.1),
                    AppColors.accent.withOpacity(0.4),
                    AppColors.accent),
            ],
          ),
        ),

        // ── Table ────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: StreamBuilder<List<DealModel>>(
              stream: _dealsStream,
              builder: (ctx, snap) {
                if (_dealsStream == null) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent));
                }

                final all   = snap.data ?? [];
                final deals = _applyFilters(all, user);
                final cols  = user.isAdmin ? _colsAdmin : _colsOther;

                if (_groupByStatus) {
                  return _GroupedDealsTable(
                    deals:      deals,
                    cols:       cols,
                    user:       user,
                    isDark:     isDark,
                    collapsed:  _collapsed,
                    surface:    surface,
                    border:     border,
                    textColor:  textColor,
                    text2:      text2,
                    salesUsers: _salesUsers,
                    onToggle:   (s) => setState(() {
                      _collapsed.contains(s)
                          ? _collapsed.remove(s)
                          : _collapsed.add(s);
                    }),
                    onEdit:   (d) => _openDealForm(context, user, d),
                    onDelete: (d) => _confirmDelete(context, d),
                    onAssign: (d) => _openAssignForm(context, user, d),
                  );
                }

                return StickyTable(
                  columns: cols,
                  isDark: isDark,
                  emptyMessage: 'No deals found',
                  emptySubMessage:
                  'Click "+ Add Deal" to add your first deal',
                  emptyIcon: Icons.attach_money,
                  rows: deals
                      .map((d) => _buildDealCells(
                      d, user, isDark, context))
                      .toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDealCells(
      DealModel d, UserModel user, bool isDark, BuildContext context) {
    final tc  = isDark ? AppColors.darkText  : AppColors.lightText;
    final t2c = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final cells = <Widget>[];

    cells.add(tCell(
        d.taskCode.isNotEmpty ? d.taskCode : d.id.substring(0, 8),
        color: AppColors.accent, mono: true, fontSize: 11));

    if (user.isAdmin) {
      cells.add(_salesNameCell(d.salesName, d.salesId, t2c, tc));
    }

    cells.addAll([
      tCell(d.date, color: t2c, fontSize: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(d.clientName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: tc)),
      ),
      tCell(d.wordCount, color: t2c, fontSize: 12),
      tCell('\$${d.totalDealValue}',
          color: AppColors.green, mono: true, bold: true, fontSize: 13),
      tCell(d.payment1st.isEmpty ? '-' : '\$${d.payment1st}',
          color: t2c, fontSize: 12, mono: true),
      tCell(d.payment2nd.isEmpty ? '-' : '\$${d.payment2nd}',
          color: t2c, fontSize: 12, mono: true),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: StatusBadge.forPayment(d.paymentStatus)),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: StatusBadge.forAssign(d.assignStatus)),
      tCell(d.writerAssigned.isEmpty ? '-' : d.writerAssigned,
          color: t2c, fontSize: 12),
      tCell(d.notes.isEmpty ? '-' : d.notes, color: t2c, fontSize: 12),
      d.salesFileLink.isNotEmpty
          ? _urlBtn('📁 File', d.salesFileLink)
          : tCell('-', color: t2c),
      d.paymentScreenshot.isNotEmpty
          ? _urlBtn('🧾 View', d.paymentScreenshot)
          : tCell('-', color: t2c),
      tActions([
        if (user.isSales || user.isAdmin)
          tAction('Edit', AppColors.accent,
                  () => _openDealForm(context, user, d)),
        if (user.isAdmin)
          tAction('Del', AppColors.red,
                  () => _confirmDelete(context, d)),
        if ((user.isSales || user.isAdmin) && d.assignStatus != 'Assigned')
          tAction('Assign', AppColors.green,
                  () => _openAssignForm(context, user, d)),
      ]),
    ]);

    return cells;
  }

  Widget _headerChip({
    required IconData icon,
    required String label,
    required bool active,
    required Color surface,
    required Color border,
    required Color text2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withOpacity(0.10) : surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active
                  ? AppColors.accent.withOpacity(0.35)
                  : border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: active ? AppColors.accent : text2),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.accent : text2)),
        ]),
      ),
    );
  }

  Widget _salesNameCell(
      String name, String salesId, Color t2, Color tc) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final salesUser =
        _salesUsers.where((u) => u.userId == salesId).firstOrNull;
    final teamColors = {
      'Red':    AppColors.teamRed,
      'Yellow': AppColors.teamYellow,
      'Blue':   AppColors.teamBlue,
    };
    final teamColor =
        teamColors[salesUser?.team ?? ''] ?? AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: teamColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: teamColor)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tc)),
              if (salesUser?.team.isNotEmpty == true)
                Text(salesUser!.team,
                    style: TextStyle(
                        fontSize: 10,
                        color: teamColor,
                        fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _urlBtn(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            String safe = url.trim();
            if (!safe.startsWith('http')) safe = 'https://$safe';
            final uri = Uri.tryParse(safe);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border:
              Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
        ),
      ),
    );
  }

  Widget _monthPicker(
      Color surface, Color border, Color tc, Color t2) {
    final months = DateHelper.getMonthList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterMonth.isEmpty ? null : _filterMonth,
          hint: Text('All Months',
              style: TextStyle(fontSize: 12, color: t2)),
          items: months
              .map((m) => DropdownMenuItem(
              value: m,
              child: Text(m,
                  style: TextStyle(fontSize: 12, color: tc))))
              .toList(),
          onChanged: (v) => setState(() => _filterMonth = v ?? ''),
          dropdownColor: surface,
          style: TextStyle(color: tc, fontSize: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _salesPersonPicker(
      Color surface, Color border, Color tc, Color t2) {
    final teamColors = {
      'Red':    AppColors.teamRed,
      'Yellow': AppColors.teamYellow,
      'Blue':   AppColors.teamBlue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterSalesId,
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(children: [
                const Icon(Icons.people_outline,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('All Sales People',
                    style: TextStyle(fontSize: 12, color: tc)),
              ]),
            ),
            ..._salesUsers.map((u) {
              final tColor = teamColors[u.team] ?? AppColors.accent;
              return DropdownMenuItem(
                value: u.userId,
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: tColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        u.name.isNotEmpty
                            ? u.name[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: tColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('${u.name} (@${u.username})',
                      style: TextStyle(fontSize: 12, color: tc)),
                  if (u.team.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text('· ${u.team}',
                        style: TextStyle(
                            fontSize: 10,
                            color: tColor,
                            fontWeight: FontWeight.w700)),
                  ],
                ]),
              );
            }),
          ],
          onChanged: (v) =>
              setState(() => _filterSalesId = v ?? 'all'),
          dropdownColor: surface,
          style: TextStyle(color: tc, fontSize: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _quickChip(
      String label, String key,
      Color surface, Color border, Color t2) {
    final isActive = _quickDate == key;
    return GestureDetector(
      onTap: () => setState(() {
        _quickDate   = isActive ? '' : key;
        _filterMonth = '';
      }),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.12)
              : surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive
                  ? AppColors.accent.withOpacity(0.45)
                  : border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.accent : t2)),
      ),
    );
  }

  Widget _clearChipBtn(String label, VoidCallback onTap,
      Color bg, Color bd, Color tc) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: bd)),
        child: Text(label, style: TextStyle(fontSize: 12, color: tc)),
      ),
    );
  }

  InputDecoration _searchDeco(Color t2, Color surface, Color border) =>
      InputDecoration(
        hintText: 'Search by sales, client, status...',
        hintStyle: TextStyle(color: t2),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.accent)),
        prefixIcon: Icon(Icons.search, size: 16, color: t2),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      );

  void _openDealForm(
      BuildContext context, UserModel user, DealModel? deal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DealDialog(deal: deal, user: user, svc: _svc),
    );
  }

  void _openAssignForm(
      BuildContext context, UserModel user, DealModel deal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssignDialog(deal: deal, user: user, svc: _svc),
    );
  }

  void _confirmDelete(BuildContext context, DealModel deal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: const Text('Delete Deal?'),
        content: Text('Delete deal for "${deal.clientName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.deleteDeal(deal.id);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


// ─── Deal Summary Bar — matches screenshot pill style ─────────────────────────
class _DealSummaryBar extends StatelessWidget {
  final List<DealModel> deals;
  final Color bg;
  final Color text2;
  const _DealSummaryBar(
      {required this.deals, required this.bg, required this.text2});

  @override
  Widget build(BuildContext context) {
    // Count by payment status
    final counts = <String, int>{};
    for (final d in deals) {
      counts[d.paymentStatus] = (counts[d.paymentStatus] ?? 0) + 1;
    }

    // Pill definitions — label, dot color, text color
    // Matches the screenshot: total (no dot), In Talk style → Pending (blue dot),
    // Follow Up style → Partial (orange dot), Won → Paid (green dot), Lost → Overdue (red dot)
    final pills = [
      _PillData(
        label:     '${deals.length} deals',
        dot:       null,
        textColor: text2,
      ),
      _PillData(
        label:     '${counts["Pending"] ?? 0} Pending',
        dot:       const Color(0xFF3B82F6), // blue
        textColor: const Color(0xFF3B82F6),
      ),
      _PillData(
        label:     '${counts["Partial"] ?? 0} Partial',
        dot:       const Color(0xFFF59E0B), // amber/orange
        textColor: const Color(0xFFB45309),
      ),
      _PillData(
        label:     '${counts["Paid"] ?? 0} Paid',
        dot:       const Color(0xFF22C55E), // green
        textColor: const Color(0xFF16A34A),
      ),
      _PillData(
        label:     '${counts["Overdue"] ?? 0} Overdue',
        dot:       const Color(0xFFEF4444), // red
        textColor: const Color(0xFFDC2626),
      ),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: pills.map((p) => _SummaryPill(pill: p)).toList(),
      ),
    );
  }
}

/// A single summary pill — thin border, optional colored dot, bold label.
class _SummaryPill extends StatelessWidget {
  final _PillData pill;
  const _SummaryPill({super.key, required this.pill});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // Transparent background, just a subtle border — same as screenshot
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colored dot (absent for the "total" pill)
          if (pill.dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pill.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            pill.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pill.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillData {
  final String label;
  final Color? dot;
  final Color textColor;
  const _PillData({
    required this.label,
    required this.dot,
    required this.textColor,
  });
}


// ─── Grouped Deals Table ──────────────────────────────────────────────────────
class _GroupedDealsTable extends StatelessWidget {
  final List<DealModel>   deals;
  final List<TableCol>    cols;
  final UserModel         user;
  final bool              isDark;
  final Set<String>       collapsed;
  final Color             surface;
  final Color             border;
  final Color             textColor;
  final Color             text2;
  final List<UserModel>   salesUsers;
  final void Function(String)    onToggle;
  final void Function(DealModel) onEdit;
  final void Function(DealModel) onDelete;
  final void Function(DealModel) onAssign;

  const _GroupedDealsTable({
    required this.deals,
    required this.cols,
    required this.user,
    required this.isDark,
    required this.collapsed,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.salesUsers,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  static const _statusOrder = ['Pending', 'Partial', 'Paid', 'Overdue'];

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 52, color: text2),
            const SizedBox(height: 12),
            Text('No deals found',
                style: TextStyle(
                    fontSize: 15,
                    color: text2,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Click "+ Add Deal" to add your first deal',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkText3
                        : AppColors.lightText3)),
          ],
        ),
      );
    }

    final grouped = <String, List<DealModel>>{};
    for (final s in _statusOrder) {
      final g = deals.where((d) => d.paymentStatus == s).toList();
      if (g.isNotEmpty) grouped[s] = g;
    }
    for (final d in deals) {
      if (!_statusOrder.contains(d.paymentStatus)) {
        grouped.putIfAbsent(d.paymentStatus, () => []).add(d);
      }
    }

    final allRows = <List<Widget>>[];
    grouped.forEach((status, groupDeals) {
      allRows.add(_buildGroupHeaderRow(status, groupDeals.length));
      if (!collapsed.contains(status)) {
        for (int i = 0; i < groupDeals.length; i++) {
          allRows.add(_buildDataRow(groupDeals[i], i + 1, context));
        }
      }
    });

    return StickyTable(
      columns:         cols,
      isDark:          isDark,
      emptyMessage:    'No deals found',
      emptySubMessage: 'Click "+ Add Deal" to add your first deal',
      emptyIcon:       Icons.attach_money,
      rows:            allRows,
    );
  }

  List<Widget> _buildGroupHeaderRow(String status, int count) {
    final color  = _statusColor(status);
    final isOpen = !collapsed.contains(status);
    final rowBg  = isDark
        ? color.withOpacity(0.07)
        : color.withOpacity(0.05);

    final headerWidget = GestureDetector(
      onTap: () => onToggle(status),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(
            top:    BorderSide(color: color.withOpacity(0.18)),
            bottom: BorderSide(color: color.withOpacity(0.18)),
            left:   BorderSide(color: color.withOpacity(0.55), width: 3),
          ),
        ),
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: isOpen ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right,
                      size: 16, color: color.withOpacity(0.8)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:        color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(status,
                        style: TextStyle(
                            fontSize:   11.5,
                            fontWeight: FontWeight.w700,
                            color:      color)),
                  ]),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count deal${count == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      color.withOpacity(0.85)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return List.generate(cols.length, (i) {
      if (i == 0) return headerWidget;
      return GestureDetector(
        onTap: () => onToggle(status),
        child: Container(color: rowBg),
      );
    });
  }

  List<Widget> _buildDataRow(
      DealModel d, int num, BuildContext context) {
    final tc  = isDark ? AppColors.darkText  : AppColors.lightText;
    final t2c = isDark ? AppColors.darkText2 : AppColors.lightText2;
    final cells = <Widget>[];

    cells.add(tCell(
        d.taskCode.isNotEmpty ? d.taskCode : d.id.substring(0, 8),
        color: AppColors.accent, mono: true, fontSize: 11));

    if (user.isAdmin) {
      cells.add(_salesNameCell(d.salesName, d.salesId, t2c, tc));
    }

    cells.addAll([
      tCell(d.date, color: t2c, fontSize: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(d.clientName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: tc)),
      ),
      tCell(d.wordCount, color: t2c, fontSize: 12),
      tCell('\$${d.totalDealValue}',
          color: AppColors.green, mono: true, bold: true, fontSize: 13),
      tCell(d.payment1st.isEmpty ? '-' : '\$${d.payment1st}',
          color: t2c, fontSize: 12, mono: true),
      tCell(d.payment2nd.isEmpty ? '-' : '\$${d.payment2nd}',
          color: t2c, fontSize: 12, mono: true),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: StatusBadge.forPayment(d.paymentStatus)),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: StatusBadge.forAssign(d.assignStatus)),
      tCell(d.writerAssigned.isEmpty ? '-' : d.writerAssigned,
          color: t2c, fontSize: 12),
      tCell(d.notes.isEmpty ? '-' : d.notes, color: t2c, fontSize: 12),
      d.salesFileLink.isNotEmpty
          ? _urlBtn('📁 File', d.salesFileLink)
          : tCell('-', color: t2c),
      d.paymentScreenshot.isNotEmpty
          ? _urlBtn('🧾 View', d.paymentScreenshot)
          : tCell('-', color: t2c),
      tActions([
        if (user.isSales || user.isAdmin)
          tAction('Edit', AppColors.accent, () => onEdit(d)),
        if (user.isAdmin)
          tAction('Del', AppColors.red, () => onDelete(d)),
        if ((user.isSales || user.isAdmin) && d.assignStatus != 'Assigned')
          tAction('Assign', AppColors.green, () => onAssign(d)),
      ]),
    ]);

    return cells;
  }

  Widget _salesNameCell(
      String name, String salesId, Color t2, Color tc) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final salesUser =
        salesUsers.where((u) => u.userId == salesId).firstOrNull;
    final teamColors = {
      'Red':    AppColors.teamRed,
      'Yellow': AppColors.teamYellow,
      'Blue':   AppColors.teamBlue,
    };
    final teamColor =
        teamColors[salesUser?.team ?? ''] ?? AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: teamColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: teamColor)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tc)),
              if (salesUser?.team.isNotEmpty == true)
                Text(salesUser!.team,
                    style: TextStyle(
                        fontSize: 10,
                        color: teamColor,
                        fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _urlBtn(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            String safe = url.trim();
            if (!safe.startsWith('http')) safe = 'https://$safe';
            final uri = Uri.tryParse(safe);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border:
              Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':    return const Color(0xFF22C55E);
      case 'Pending': return const Color(0xFF3B82F6);
      case 'Partial': return const Color(0xFFF59E0B);
      case 'Overdue': return const Color(0xFFEF4444);
      default:        return AppColors.accent;
    }
  }
}


// ─── Deal Form Dialog ─────────────────────────────────────────────────────────
class _DealDialog extends StatefulWidget {
  final DealModel? deal;
  final UserModel user;
  final FirestoreService svc;
  const _DealDialog(
      {required this.deal, required this.user, required this.svc});
  @override
  State<_DealDialog> createState() => _DealDialogState();
}

class _DealDialogState extends State<_DealDialog> {
  final _cc  = TextEditingController();
  final _wc  = TextEditingController();
  final _tc  = TextEditingController();
  final _p1  = TextEditingController();
  final _p2  = TextEditingController();
  final _nc  = TextEditingController();
  final _sf  = TextEditingController();
  final _sc2 = TextEditingController();
  final _pc  = TextEditingController();
  final _wa  = TextEditingController();
  String _date = DateHelper.today(), _payStatus = 'Pending';
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.deal != null) {
      final d = widget.deal!;
      _cc.text  = d.clientName;
      _wc.text  = d.wordCount;
      _tc.text  = d.totalDealValue;
      _p1.text  = d.payment1st;
      _p2.text  = d.payment2nd;
      _nc.text  = d.notes;
      _sf.text  = d.salesFileLink;
      _sc2.text = d.paymentScreenshot;
      _pc.text  = d.clientProfileLink;
      _wa.text  = d.whatsappNumber;
      _date      = d.date;
      _payStatus = AppConstants.paymentStatuses.contains(d.paymentStatus)
          ? d.paymentStatus
          : 'Pending';
    }
  }

  @override
  void dispose() {
    for (final c in [_cc, _wc, _tc, _p1, _p2, _nc, _sf, _sc2, _pc, _wa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_cc.text.trim().isEmpty || _tc.text.trim().isEmpty) {
      setState(() => _error = 'Client name and total value are required');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      final deal = DealModel(
        id:               widget.deal?.id ?? '',
        taskCode:         widget.deal?.taskCode ?? '',
        date:             _date,
        salesId:          widget.user.userId,
        salesName:        widget.user.name,
        team:             widget.user.team,
        clientName:       _cc.text.trim(),
        wordCount:        _wc.text.trim(),
        totalDealValue:   _tc.text.trim(),
        payment1st:       _p1.text.trim(),
        payment2nd:       _p2.text.trim(),
        paymentStatus:    _payStatus,
        notes:            _nc.text.trim(),
        salesFileLink:    _sf.text.trim(),
        paymentScreenshot: _sc2.text.trim(),
        clientProfileLink: _pc.text.trim(),
        whatsappNumber:   _wa.text.trim(),
      );
      if (widget.deal == null) {
        await widget.svc.addDeal(deal);
      } else {
        await widget.svc.updateDeal(widget.deal!.id, deal.toMap());
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.deal == null
                ? '✅ Deal added!'
                : '✅ Deal updated!'),
            backgroundColor: AppColors.green));
      }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText      : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2     : AppColors.lightText2;
    final s2        = isDark ? AppColors.darkSurface2  : AppColors.lightSurface2;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
            child: Row(children: [
              Text(
                widget.deal == null ? 'Add Deal' : 'Edit Deal',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor),
              ),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (widget.deal != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.3))),
                    child: Text(
                        'Task ID: ${widget.deal!.taskCode}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                  ),
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.red.withOpacity(0.3))),
                    child: Text(_error,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.red)),
                  ),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  _f('Client Name *', _cc, textColor, text2, w: 290),
                  _f('Word Count', _wc, textColor, text2,
                      w: 140, kb: TextInputType.number),
                  _f('Total Deal Value (AUD) *', _tc, textColor, text2,
                      w: 190, kb: TextInputType.number),
                  _f('1st Payment (AUD)', _p1, textColor, text2,
                      w: 165, kb: TextInputType.number),
                  _f('2nd Payment (AUD)', _p2, textColor, text2,
                      w: 165, kb: TextInputType.number),
                  _drop('Payment Status',
                      AppConstants.paymentStatuses,
                      _payStatus,
                          (v) => setState(() => _payStatus = v!),
                      textColor, text2, s2),
                  _f('Task File Link (Drive)', _sf, textColor, text2,
                      w: 350),
                  _f('Payment Screenshot Link', _sc2, textColor, text2,
                      w: 350),
                  _f('Client Profile Link', _pc, textColor, text2,
                      w: 290),
                  _f('WhatsApp Number', _wa, textColor, text2),
                  _f('Notes', _nc, textColor, text2, w: 620, lines: 3),
                ]),
              ]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                  child: _saving
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : Text(
                      widget.deal == null
                          ? 'Save Deal'
                          : 'Update Deal',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _f(String lbl, TextEditingController ctrl,
      Color tc, Color t2,
      {double w = 180, int lines = 1, TextInputType? kb}) =>
      SizedBox(
        width: w,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lbl,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t2)),
              const SizedBox(height: 5),
              TextField(
                  controller: ctrl,
                  maxLines: lines,
                  keyboardType: kb,
                  style: TextStyle(fontSize: 13, color: tc),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10))),
            ]),
      );

  Widget _drop(String lbl, List<String> items, String val,
      ValueChanged<String?> onChange,
      Color tc, Color t2, Color s2) =>
      SizedBox(
        width: 180,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lbl,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t2)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: items.contains(val) ? val : items.first,
                items: items
                    .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: TextStyle(fontSize: 13, color: tc))))
                    .toList(),
                onChanged: onChange,
                dropdownColor: s2,
                style: TextStyle(fontSize: 13, color: tc),
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
              ),
            ]),
      );
}


// ─── Assign Dialog ────────────────────────────────────────────────────────────
class _AssignDialog extends StatefulWidget {
  final DealModel deal;
  final UserModel user;
  final FirestoreService svc;
  const _AssignDialog(
      {required this.deal, required this.user, required this.svc});
  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final _subCtrl     = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _salesIdCtrl = TextEditingController();
  String _type = 'Essay', _priority = 'Medium',
      _deadline = '', _wId = '', _wName = '';
  List<UserModel> _writers = [];
  bool _loadingW = true, _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _subCtrl.text = widget.deal.clientName;
    _loadW();
  }

  @override
  void dispose() {
    _subCtrl.dispose();
    _notesCtrl.dispose();
    _salesIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadW() async {
    final w = await widget.svc.getWriters();
    if (mounted) {
      setState(() {
        _writers = w;
        if (w.isNotEmpty) {
          _wId   = w.first.userId;
          _wName = w.first.name;
        }
        _loadingW = false;
      });
    }
  }

  Future<void> _save() async {
    if (_subCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Subject required');
      return;
    }
    if (_deadline.isEmpty) {
      setState(() => _error = 'Deadline required');
      return;
    }
    if (_wId.isEmpty) {
      setState(() => _error = 'Select a writer');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    final task = TaskModel(
      taskId:         '',
      dateAssigned:   DateHelper.today(),
      dealId:         widget.deal.id,
      salesId:        widget.deal.salesId,//remove user and add deals add new
      salesName:      widget.deal.salesName, //remove user and add deals add new
      salesTeam:      widget.deal.team, //remove user and add deals  add new
      writerId:       _wId,
      writerName:     _wName,
      clientName:     widget.deal.clientName,
      subject:        _subCtrl.text.trim(),
      assignmentType: _type,
      wordCount:      widget.deal.wordCount,
      deadline:       _deadline,
      status:         'Pending',
      priority:       _priority,
      notes:          _notesCtrl.text.trim(),
      salesFileLink:  widget.deal.salesFileLink,
      salesTaskId:    _salesIdCtrl.text.trim(),
    );
    await widget.svc.assignTask(task, widget.deal.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Assigned to $_wName!'),
          backgroundColor: AppColors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final s2      = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border  = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final tc      = isDark ? AppColors.darkText      : AppColors.lightText;
    final t2      = isDark ? AppColors.darkText2     : AppColors.lightText2;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
            child: Row(children: [
              Text('Assign to Writer',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tc)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingW
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.3))),
                  child: Text(
                      'Client: ${widget.deal.clientName}'
                          '  •  Code: ${widget.deal.taskCode}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600)),
                ),
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.red.withOpacity(0.3))),
                    child: Text(_error,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.red)),
                  ),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  SizedBox(
                    width: 260,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Writer *',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t2)),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: _wId.isEmpty ? null : _wId,
                            hint: Text('Select writer',
                                style: TextStyle(
                                    fontSize: 13, color: t2)),
                            items: _writers
                                .map((w) => DropdownMenuItem(
                              value: w.userId,
                              child: Text(
                                  '${w.name} (@${w.username})',
                                  style: TextStyle(
                                      fontSize: 13, color: tc)),
                            ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _wId   = v;
                                _wName = _writers
                                    .firstWhere(
                                        (w) => w.userId == v)
                                    .name;
                              });
                            },
                            dropdownColor: s2,
                            style: TextStyle(fontSize: 13, color: tc),
                            decoration: const InputDecoration(
                                contentPadding:
                                EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10)),
                          ),
                        ]),
                  ),
                  _f('Subject *', _subCtrl, tc, t2, w: 260),
                  _drop('Assignment Type',
                      AppConstants.assignmentTypes, _type,
                          (v) => setState(() => _type = v!),
                      tc, t2, s2),
                  _drop('Priority', AppConstants.priorities,
                      _priority,
                          (v) => setState(() => _priority = v!),
                      tc, t2, s2),
                  SizedBox(
                    width: 180,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Deadline *',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t2)),
                          const SizedBox(height: 5),
                          InkWell(
                            onTap: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now()
                                    .add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (p != null) {
                                setState(() =>
                                _deadline = DateHelper.format(p));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: s2,
                                borderRadius:
                                BorderRadius.circular(8),
                                border: Border.all(color: border),
                              ),
                              child: Row(children: [
                                Icon(Icons.calendar_today,
                                    size: 14, color: t2),
                                const SizedBox(width: 8),
                                Text(
                                  _deadline.isEmpty
                                      ? 'Pick a date'
                                      : _deadline,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _deadline.isEmpty
                                          ? t2
                                          : tc),
                                ),
                              ]),
                            ),
                          ),
                        ]),
                  ),
                  _f('Sales Task ID (optional)', _salesIdCtrl,
                      tc, t2, w: 200),
                  _f('Notes for Writer', _notesCtrl, tc, t2,
                      w: 510, lines: 3),
                ]),
              ]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                  child: _saving
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Assign Task',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _f(String lbl, TextEditingController ctrl,
      Color tc, Color t2,
      {double w = 180, int lines = 1}) =>
      SizedBox(
        width: w,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lbl,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t2)),
              const SizedBox(height: 5),
              TextField(
                  controller: ctrl,
                  maxLines: lines,
                  style: TextStyle(fontSize: 13, color: tc),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10))),
            ]),
      );

  Widget _drop(String lbl, List<String> items, String val,
      ValueChanged<String?> onChange,
      Color tc, Color t2, Color s2) =>
      SizedBox(
        width: 180,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lbl,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t2)),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: items.contains(val) ? val : items.first,
                items: items
                    .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: TextStyle(fontSize: 13, color: tc))))
                    .toList(),
                onChanged: onChange,
                dropdownColor: s2,
                style: TextStyle(fontSize: 13, color: tc),
                decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10)),
              ),
            ]),
      );
}