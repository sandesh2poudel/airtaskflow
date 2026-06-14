// lib/screens/leads/leads_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/lead_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/sticky_table.dart';
import '../../widgets/status_badge.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _svc        = FirestoreService();
  final _searchCtrl = TextEditingController();

  String _searchQuery   = '';
  String _filterMonth   = _currentMonthKey();
  String _filterStatus  = '';
  String _filterSource  = '';
  String _quickDate     = '';

  // Admin only
  String          _filterSalesId = 'all';
  List<UserModel> _salesUsers    = [];

// Group by status
  bool            _groupByStatus = false;
  final Set<String> _collapsed   = {};

  // Density
  _Density _density = _Density.comfortable;

  // ── PAGINATION STATE ─────────────────────────────────────────
  List<LeadModel> _leads      = [];
  bool   _loading             = true;
  int    _currentPage         = 1;
  bool   _hasMore             = false;

  // Cursor stacks: index 0 = page 1 start (always null), index N = page N+1 start
  // We store the lastDoc of each page so we can go forward,
  // and the firstDoc of each page so we can reconstruct "go back".
  // Simpler approach: keep a stack of startAfter cursors.
  // cursorStack[0] = null (page 1 has no cursor)
  // cursorStack[1] = lastDoc of page 1  (start of page 2)
  final List<DocumentSnapshot?> _cursorStack = [null];

  // Stream for summary bar ONLY (small, always up-to-date)
//  Stream<List<LeadModel>>? _leadsStream;
  bool _streamInitialized = false;

  // ── Column definitions ────────────────────────────────────────
  static const _cols = [
    TableCol('#',            45),
    TableCol('Client Name', 150),
    TableCol('Status',      125),
    TableCol('Date',        105),
    TableCol('Sales Person',140),
    TableCol('Source',      105),
    TableCol('Subject/Task',170),
    TableCol('Remarks',     180),
    TableCol('Follow Up',   130),
    TableCol('WhatsApp',    135),
    TableCol('Actions',     110),
  ];

  static const _colsNoSales = [
    TableCol('#',            45),
    TableCol('Client Name', 150),
    TableCol('Status',      125),
    TableCol('Date',        105),
    TableCol('Source',      105),
    TableCol('Subject/Task',170),
    TableCol('Remarks',     180),
    TableCol('Follow Up',   130),
    TableCol('WhatsApp',    135),
    TableCol('Actions',     110),
  ];

  static String _currentMonthKey() {
    final now = DateTime.now();
    final m   = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      _streamInitialized = true;
      final user = context.read<AuthProvider>().currentUser!;
      // Stream used ONLY for the summary bar (lightweight, real-time)
//      _leadsStream = _svc.leadsStream(user);
      _loadSalesUsers(user);
      _fetchPage(); // load first page
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
      setState(() => _salesUsers = all.where((u) => u.isSales).toList());
    }
  }

  // ── Fetch a page using the cursor at cursorStack[currentPage - 1] ──
  Future<void> _fetchPage() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final user   = context.read<AuthProvider>().currentUser!;
    final cursor = _cursorStack[_currentPage - 1];

    // Month filter is always applied client-side inside the service
    // so no composite Firestore indexes are required
    final result = await _svc.getLeadsPaginated(
      user: user,
      filterMonth: _quickDate.isEmpty ? _filterMonth : '',
      startAfter: cursor,
    );

    if (!mounted) return;

    // Save the next-page cursor if we don't have it yet
    if (_cursorStack.length <= _currentPage) {
      _cursorStack.add(result.lastDoc);
    }

    setState(() {
      _leads   = result.items;
      _hasMore = result.hasMore;
      _loading = false;
    });
  }

  void _goNextPage() {
    setState(() => _currentPage++);
    _fetchPage();
  }

  void _goPrevPage() {
    if (_currentPage <= 1) return;
    setState(() => _currentPage--);
    _fetchPage();
  }

  // When filters change we reset to page 1
  void _resetPagination() {
    _currentPage = 1;
    _cursorStack
      ..clear()
      ..add(null);
    _fetchPage();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Quick date helper ─────────────────────────────────────────
  bool _matchesQuickDate(String leadDate) {
    if (_quickDate.isEmpty) return true;
    final now = DateTime.now();
    DateTime? d;
    try {
      d = DateTime.parse(leadDate);
    } catch (_) {
      return false;
    }
    switch (_quickDate) {
      case 'today':
        return d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd   = weekStart.add(const Duration(days: 6));
        return !d.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day)) &&
            !d.isAfter(
                DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59));
      case 'month':
        return d.year == now.year && d.month == now.month;
      default:
        return true;
    }
  }

  bool get _hasActiveFilters =>
      _filterMonth != _currentMonthKey() ||
          _filterStatus.isNotEmpty ||
          _filterSource.isNotEmpty ||
          _quickDate.isNotEmpty    ||
          _filterSalesId != 'all'  ||
          _searchQuery.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _filterMonth   = _currentMonthKey();
      _filterStatus  = '';
      _filterSource  = '';
      _quickDate     = '';
      _filterSalesId = 'all';
      _searchQuery   = '';
      _searchCtrl.clear();
    });
    _resetPagination();
  }

  // ── Apply CLIENT-SIDE filters (status, source, salesId, search, quickDate) ──
  // Month filter is already applied by Firestore — we don't repeat it here
  // unless quickDate is active (in which case month was not sent to Firestore).
  List<LeadModel> _applyFilters(List<LeadModel> leads, UserModel user) {
    var filtered = leads;

    if (user.isAdmin && _filterSalesId != 'all') {
      filtered = filtered.where((l) => l.salesId == _filterSalesId).toList();
    }

    // quickDate is always client-side
    if (_quickDate.isNotEmpty) {
      filtered = filtered.where((l) => _matchesQuickDate(l.date)).toList();
    }

    if (_filterStatus.isNotEmpty) {
      filtered = filtered.where((l) => l.dealClosingStatus == _filterStatus).toList();
    }

    if (_filterSource.isNotEmpty) {
      filtered = filtered.where((l) => l.source == _filterSource).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((l) =>
          '${l.salesName} ${l.clientName} '
              '${l.dealClosingStatus} ${l.subjectsTask} '
              '${l.source} ${l.remarks} ${l.whatsappNumber}'
              .toLowerCase()
              .contains(_searchQuery)).toList();
    }

    return filtered;
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user      = context.watch<AuthProvider>().currentUser!;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2    : AppColors.lightText2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ══ ROW 1 — Title + action buttons ════════════════════
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: isMobile
                  ? _buildHeaderMobile(context, user, bg, surface, border, textColor, text2)
                  : _buildHeaderDesktop(context, user, bg, surface, border, textColor, text2),
            ),

            // ══ ROW 2 — Summary pills (from stream — always up to date) ══
    /**        StreamBuilder<List<LeadModel>>(
              stream: _leadsStream,
              builder: (ctx, snap) {
                if (_leadsStream == null) return const SizedBox.shrink();
                final all      = snap.data ?? [];
                final filtered = _applyFilters(all, user);
                return _SummaryBar(leads: filtered, bg: bg, text2: text2);
              },
            ),*/
            _SummaryBar(
              leads: _applyFilters(_leads, user),
              bg: bg,
              text2: text2,
            ),

            // ══ ROW 3 — Search ════════════════════════════════════
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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

            // ══ ROW 4 — Filters + Density ════════════════════════
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: isMobile
                  ? _buildFiltersMobile(user, surface, border, textColor, text2)
                  : _buildFiltersDesktop(user, surface, border, textColor, text2),
            ),

            // ══ TABLE ═════════════════════════════════════════════
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(child: _buildTable(user, isDark, textColor, text2)),

                    // ── Pagination bar ────────────────────────────
                    PaginationBar(
                      currentPage: _currentPage,
                      hasMore: _hasMore,
                      isLoading: _loading,
                      onPrev: _currentPage > 1 ? _goPrevPage : null,
                      onNext: _goNextPage,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTable(
      UserModel user, bool isDark, Color textColor, Color text2) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    final leads = _applyFilters(_leads, user);
    final cols  = user.isAdmin ? _cols : _colsNoSales;
    final rowPad = _rowPadding(_density);

    // ── Group by status ───────────────────────────────────────
    if (_groupByStatus) {
      return _GroupedTable(
        leads:       leads,
        cols:        cols,
        user:        user,
        isDark:      isDark,
        rowPad:      rowPad,
        collapsed:   _collapsed,
        surface:     Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface : AppColors.lightSurface,
        border:      Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBorder : AppColors.lightBorder,
        textColor:   textColor,
        text2:       text2,
        onToggle:    (s) => setState(() {
          _collapsed.contains(s)
              ? _collapsed.remove(s)
              : _collapsed.add(s);
        }),
        onEdit:      (l) => _openForm(context, user, l),
        onDelete:    (l) => _confirmDelete(context, l),
        emptySubMsg: _hasActiveFilters
            ? 'Try clearing some filters'
            : 'Click \"+ Add Lead\" to add your first lead',
      );
    }

    // ── Flat table ────────────────────────────────────────────
    return StickyTable(
      columns:        cols,
      isDark:         isDark,
      pinnedCount:    3,
      emptyMessage:   'No leads found',
      emptySubMessage: _hasActiveFilters
          ? 'Try clearing some filters'
          : 'Click \"+ Add Lead\" to add your first lead',
      emptyIcon:      Icons.inbox_outlined,
      rows: _buildRows(
          leads, user, cols, isDark, rowPad,
          textColor, text2, context),
    );
  }

  // ── Desktop header ────────────────────────────────────────────
  Widget _buildHeaderDesktop(
      BuildContext context, UserModel user,
      Color bg, Color surface, Color border,
      Color textColor, Color text2) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Data Collection',
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
            Text('Track your daily leads and prospects',
                style: TextStyle(fontSize: 12, color: text2)),
          ],
        ),
      ),
      _headerChip(
        icon: Icons.table_rows_outlined,
        label: 'Group by status',
        active: _groupByStatus,
        surface: surface,
        border: border,
        text2: text2,
        onTap: () => setState(() => _groupByStatus = !_groupByStatus),
      ),
      const SizedBox(width: 8),
      ElevatedButton.icon(
        onPressed: () => _openForm(context, user, null),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text('Add Lead',
            style: TextStyle(color: Colors.white, fontSize: 13)),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10)),
      ),
    ]);
  }

  // ── Mobile header ─────────────────────────────────────────────
  Widget _buildHeaderMobile(
      BuildContext context, UserModel user,
      Color bg, Color surface, Color border,
      Color textColor, Color text2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Data Collection',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  if (_filterMonth.isNotEmpty || _quickDate.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _quickDate.isNotEmpty
                            ? '· ${_quickDateLabel(_quickDate)}'
                            : '· $_filterMonth',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: text2,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                ]),
                Text('Track your daily leads and prospects',
                    style: TextStyle(fontSize: 11, color: text2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _groupByStatus = !_groupByStatus),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _groupByStatus
                    ? AppColors.accent.withOpacity(0.10)
                    : surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _groupByStatus
                        ? AppColors.accent.withOpacity(0.35)
                        : border),
              ),
              child: Icon(Icons.table_rows_outlined,
                  size: 16,
                  color: _groupByStatus ? AppColors.accent : text2),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _openForm(context, user, null),
            icon: const Icon(Icons.add, size: 14, color: Colors.white),
            label: const Text('Add',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8)),
          ),
        ]),
      ],
    );
  }

  // ── Desktop filters row ───────────────────────────────────────
  Widget _buildFiltersDesktop(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return Row(children: [
      Expanded(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _filterChips(user, surface, border, textColor, text2),
        ),
      ),
      const SizedBox(width: 12),
      _densityToggle(surface, border, text2),
    ]);
  }

  // ── Mobile filters (stacked) ──────────────────────────────────
  Widget _buildFiltersMobile(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickChip('Today',      'today', surface, border, text2),
              const SizedBox(width: 6),
              _quickChip('This Week',  'week',  surface, border, text2),
              const SizedBox(width: 6),
              _quickChip('This Month', 'month', surface, border, text2),
              const SizedBox(width: 12),
              _densityToggle(surface, border, text2),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _monthPicker(surface, border, textColor, text2),
              const SizedBox(width: 6),
              _statusPicker(surface, border, textColor, text2),
              const SizedBox(width: 6),
              _sourcePicker(surface, border, textColor, text2),
              if (user.isAdmin && _salesUsers.isNotEmpty) ...[
                const SizedBox(width: 6),
                _salesPersonPicker(surface, border, textColor, text2),
              ],
              if (_filterStatus.isNotEmpty) ...[
                const SizedBox(width: 6),
                _clearChip('✕ $_filterStatus',
                        () => setState(() => _filterStatus = ''),
                    surface, border, text2),
              ],
              if (_filterSource.isNotEmpty) ...[
                const SizedBox(width: 6),
                _clearChip('✕ $_filterSource',
                        () => setState(() => _filterSource = ''),
                    surface, border, text2),
              ],
              if (user.isAdmin && _filterSalesId != 'all') ...[
                const SizedBox(width: 6),
                _clearChip('✕ Show All',
                        () => setState(() => _filterSalesId = 'all'),
                    surface, border, text2),
              ],
              if (_hasActiveFilters) ...[
                const SizedBox(width: 6),
                _clearChip('Clear All', _clearAllFilters,
                    AppColors.accent.withOpacity(0.1),
                    AppColors.accent.withOpacity(0.4),
                    AppColors.accent),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared filter chips list ──────────────────────────────────
  List<Widget> _filterChips(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return [
      _quickChip('Today',      'today', surface, border, text2),
      _quickChip('This Week',  'week',  surface, border, text2),
      _quickChip('This Month', 'month', surface, border, text2),
      _monthPicker(surface, border, textColor, text2),
      _statusPicker(surface, border, textColor, text2),
      _sourcePicker(surface, border, textColor, text2),
      if (user.isAdmin && _salesUsers.isNotEmpty)
        _salesPersonPicker(surface, border, textColor, text2),
      if (_filterStatus.isNotEmpty)
        _clearChip('✕ $_filterStatus',
                () => setState(() => _filterStatus = ''),
            surface, border, text2),
      if (_filterSource.isNotEmpty)
        _clearChip('✕ $_filterSource',
                () => setState(() => _filterSource = ''),
            surface, border, text2),
      if (user.isAdmin && _filterSalesId != 'all')
        _clearChip('✕ Show All',
                () => setState(() => _filterSalesId = 'all'),
            surface, border, text2),
      if (_hasActiveFilters)
        _clearChip('Clear All', _clearAllFilters,
            AppColors.accent.withOpacity(0.1),
            AppColors.accent.withOpacity(0.4),
            AppColors.accent),
    ];
  }

  // ── Build flat rows list ──────────────────────────────────────
  List<List<Widget>> _buildRows(
      List<LeadModel> leads,
      UserModel user,
      List<TableCol> cols,
      bool isDark,
      EdgeInsets rowPad,
      Color textColor,
      Color text2,
      BuildContext context,
      ) {
    // Row numbers are relative to page: page 1 starts at 1, page 2 at 101, etc.
    final offset = (_currentPage - 1) * 100;
    return leads.asMap().entries.map((e) {
      final i = e.key;
      final l = e.value;
      return _rowCells(offset + i + 1, l, user, rowPad, textColor, text2, context);
    }).toList();
  }

  List<Widget> _rowCells(
      int num,
      LeadModel l,
      UserModel user,
      EdgeInsets rowPad,
      Color textColor,
      Color text2,
      BuildContext context,
      ) {
    final cells = <Widget>[];
    cells.add(tCell('$num', color: text2, fontSize: 11));
    cells.add(_clientCell(l.clientName, rowPad));
    cells.add(_statusCell(l.dealClosingStatus, rowPad));
    cells.add(tCell(l.date, color: text2, fontSize: 12));
    if (user.isAdmin) {
      cells.add(_salesNameCell(l.salesName, text2, textColor));
    }
    cells.add(tCell(l.source, color: text2, fontSize: 12));
    cells.add(tCell(l.subjectsTask, color: textColor, fontSize: 12));
    cells.add(l.remarks.isEmpty ? tCell('-', color: text2) : _remarksCell(l.remarks, text2));
    cells.add(tCell(l.followupTextCall, color: text2, fontSize: 12));
    cells.add(tCell(l.whatsappNumber, fontSize: 11, mono: true));
    cells.add(tActions([
      if (user.isSales || user.isAdmin)
        tAction('Edit', AppColors.accent,
                () => _openForm(context, user, l)),
      if (user.isAdmin)
        tAction('Del', AppColors.red,
                () => _confirmDelete(context, l)),
    ]));
    return cells;
  }

  Widget _clientCell(String name, EdgeInsets pad) => Padding(
    padding: pad,
    child: Text(name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.accent)),
  );

  Widget _statusCell(String status, EdgeInsets pad) => Padding(
    padding: pad,
    child: StatusBadge.forLeadStatus(status),
  );

  // ── Header chip ───────────────────────────────────────────────
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
          Icon(icon, size: 14,
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

  // ── Quick date chip ───────────────────────────────────────────
  Widget _quickChip(
      String label, String key,
      Color surface, Color border, Color t2) {
    final isActive = _quickDate == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _quickDate   = isActive ? '' : key;
          _filterMonth = '';
        });
        _resetPagination();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

  // ── Month picker ──────────────────────────────────────────────
  Widget _monthPicker(
      Color surface, Color border, Color tc, Color t2) {
    final months = DateHelper.getMonthList();
    return _dropdownBox(
      surface: surface,
      border: border,
      active: _filterMonth.isNotEmpty,
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
        onChanged: (v) {
          setState(() {
            _filterMonth = v ?? '';
            _quickDate   = '';
          });
          _resetPagination();
        },
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true,
        underline: const SizedBox(),
      ),
    );
  }

  // ── Status filter ─────────────────────────────────────────────
  Widget _statusPicker(
      Color surface, Color border, Color tc, Color t2) {
    return _dropdownBox(
      surface: surface,
      border: border,
      active: _filterStatus.isNotEmpty,
      child: DropdownButton<String>(
        value: _filterStatus.isEmpty ? null : _filterStatus,
        hint: Text('All Status',
            style: TextStyle(fontSize: 12, color: t2)),
        items: AppConstants.leadStatuses
            .map((s) => DropdownMenuItem(
            value: s,
            child: Text(s,
                style: TextStyle(fontSize: 12, color: tc))))
            .toList(),
        onChanged: (v) => setState(() => _filterStatus = v ?? ''),
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true,
        underline: const SizedBox(),
      ),
    );
  }

  // ── Source filter ─────────────────────────────────────────────
  Widget _sourcePicker(
      Color surface, Color border, Color tc, Color t2) {
    return _dropdownBox(
      surface: surface,
      border: border,
      active: _filterSource.isNotEmpty,
      child: DropdownButton<String>(
        value: _filterSource.isEmpty ? null : _filterSource,
        hint: Text('All Sources',
            style: TextStyle(fontSize: 12, color: t2)),
        items: AppConstants.leadSources
            .map((s) => DropdownMenuItem(
            value: s,
            child: Text(s,
                style: TextStyle(fontSize: 12, color: tc))))
            .toList(),
        onChanged: (v) => setState(() => _filterSource = v ?? ''),
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true,
        underline: const SizedBox(),
      ),
    );
  }

  // ── Sales person picker (ADMIN ONLY) ─────────────────────────
  Widget _salesPersonPicker(
      Color surface, Color border, Color tc, Color t2) {
    return _dropdownBox(
      surface: surface,
      border: border,
      active: _filterSalesId != 'all',
      minWidth: 160,
      child: DropdownButton<String>(
        value: _filterSalesId,
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('All Sales People',
                  style: TextStyle(fontSize: 12, color: tc)),
            ]),
          ),
          ..._salesUsers.map((u) => DropdownMenuItem(
            value: u.userId,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${u.name} (@${u.username})',
                  style: TextStyle(fontSize: 12, color: tc)),
              if (u.team.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text('· ${u.team}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.darkText3)),
              ],
            ]),
          )),
        ],
        onChanged: (v) {
          setState(() => _filterSalesId = v ?? 'all');
          // salesId filter is client-side, no need to reset pagination
        },
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true,
        underline: const SizedBox(),
      ),
    );
  }

  // ── Shared dropdown box wrapper ───────────────────────────────
  Widget _dropdownBox({
    required Color surface,
    required Color border,
    required Widget child,
    bool active = false,
    double minWidth = 0,
  }) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withOpacity(0.08)
            : surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active
                ? AppColors.accent.withOpacity(0.4)
                : border),
      ),
      child: child,
    );
  }

  // ── Density toggle ────────────────────────────────────────────
  Widget _densityToggle(Color surface, Color border, Color t2) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _densityBtn('Compact',     _Density.compact,     surface, border, t2),
        _densityBtn('Comfortable', _Density.comfortable, surface, border, t2),
        _densityBtn('Spacious',    _Density.spacious,    surface, border, t2),
      ]),
    );
  }

  Widget _densityBtn(
      String label, _Density d,
      Color surface, Color border, Color t2) {
    final isActive = _density == d;
    return GestureDetector(
      onTap: () => setState(() => _density = d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withOpacity(0.12)
              : surface,
          border: Border(
              right: BorderSide(
                  color: border,
                  width: d != _Density.spacious ? 1 : 0)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.accent : t2)),
      ),
    );
  }

  // ── Clear chip ────────────────────────────────────────────────
  Widget _clearChip(String label, VoidCallback onTap,
      Color bg, Color bd, Color tc) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: bd)),
        child: Text(label, style: TextStyle(fontSize: 12, color: tc)),
      ),
    );
  }

  // ── Sales person name cell ────────────────────────────────────
  Widget _salesNameCell(String name, Color text2, Color textColor) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
        ),
      ]),
    );
  }

  Widget _remarksCell(String remarks, Color t2c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Tooltip(
        message: remarks,
        preferBelow: true,
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                remarks,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: t2c),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12, color: t2c),
          ],
        ),
      ),
    );
  }

  // ── Search decoration ─────────────────────────────────────────
  InputDecoration _searchDeco(Color t2, Color surface, Color border) =>
      InputDecoration(
        hintText: 'Search client, source...',
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

  String _quickDateLabel(String key) {
    switch (key) {
      case 'today': return 'Today';
      case 'week':  return 'This Week';
      case 'month': return 'This Month';
      default:      return '';
    }
  }

  EdgeInsets _rowPadding(_Density d) {
    switch (d) {
      case _Density.compact:     return const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
      case _Density.comfortable: return const EdgeInsets.symmetric(horizontal: 10, vertical: 9);
      case _Density.spacious:    return const EdgeInsets.symmetric(horizontal: 10, vertical: 14);
    }
  }

  void _openForm(BuildContext context, UserModel user, LeadModel? lead) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeadDialog(
        lead: lead,
        user: user,
        svc: _svc,
        onSaved: (savedLead) {
          setState(() {
            if (lead == null) {
              _leads.insert(0, savedLead);
            } else {
              final idx = _leads.indexWhere((l) => l.id == savedLead.id);
              if (idx != -1) _leads[idx] = savedLead;
            }
          });
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, LeadModel lead) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: const Text('Delete Lead?'),
        content: Text('Delete lead for "${lead.clientName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.deleteLead(lead.id);
              setState(() => _leads.removeWhere((l) => l.id == lead.id));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Lead deleted'),
                        backgroundColor: AppColors.red));
              }
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

// ─── Density enum ─────────────────────────────────────────────────────────────
enum _Density { compact, comfortable, spacious }

// ─── Summary Bar ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<LeadModel> leads;
  final Color bg;
  final Color text2;
  const _SummaryBar(
      {required this.leads, required this.bg, required this.text2});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final l in leads) {
      counts[l.dealClosingStatus] =
          (counts[l.dealClosingStatus] ?? 0) + 1;
    }

    final pills = [
      _PillData('${leads.length} leads',                  null,                    const Color(0xFF6B7280), false),
      _PillData('${counts['In Talk']   ?? 0} In Talk',    const Color(0xFF6366F1), const Color(0xFF4338CA), true),
      _PillData('${counts['Follow Up'] ?? 0} Follow Up',  const Color(0xFFF59E0B), const Color(0xFF92400E), true),
      _PillData('${counts['Won']       ?? 0} Won',        const Color(0xFF22C55E), const Color(0xFF166534), true),
      _PillData('${counts['Lost']      ?? 0} Lost',       const Color(0xFFF43F5E), const Color(0xFF9F1239), true),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: pills.map((p) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (p.dot != null) ...[
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: p.dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(p.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.textColor)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _PillData {
  final String label;
  final Color? dot;
  final Color textColor;
  final bool hasDot;
  const _PillData(this.label, this.dot, this.textColor, this.hasDot);
}

// ─── Grouped Table ────────────────────────────────────────────────────────────
// (identical to original — no changes)
class _GroupedTable extends StatelessWidget {
  final List<LeadModel>  leads;
  final List<TableCol>   cols;
  final UserModel        user;
  final bool             isDark;
  final EdgeInsets       rowPad;
  final Set<String>      collapsed;
  final Color            surface;
  final Color            border;
  final Color            textColor;
  final Color            text2;
  final void Function(String) onToggle;
  final void Function(LeadModel) onEdit;
  final void Function(LeadModel) onDelete;
  final String           emptySubMsg;

  const _GroupedTable({
    required this.leads,
    required this.cols,
    required this.user,
    required this.isDark,
    required this.rowPad,
    required this.collapsed,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.emptySubMsg,
  });

  static const _statusOrder = ['In Talk', 'Follow Up', 'Won', 'Lost'];

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 52, color: text2),
            const SizedBox(height: 12),
            Text('No leads found',
                style: TextStyle(
                    fontSize: 15,
                    color: text2,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(emptySubMsg,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkText3
                        : AppColors.lightText3)),
          ],
        ),
      );
    }

    final grouped = <String, List<LeadModel>>{};
    for (final s in _statusOrder) {
      final g = leads.where((l) => l.dealClosingStatus == s).toList();
      if (g.isNotEmpty) grouped[s] = g;
    }
    for (final l in leads) {
      if (!_statusOrder.contains(l.dealClosingStatus)) {
        grouped.putIfAbsent(l.dealClosingStatus, () => []).add(l);
      }
    }

    final allRows = <List<Widget>>[];
    grouped.forEach((status, groupLeads) {
      allRows.add(_buildGroupHeaderRow(status, groupLeads.length));
      if (!collapsed.contains(status)) {
        for (int i = 0; i < groupLeads.length; i++) {
          allRows.add(_buildDataRow(i + 1, groupLeads[i], context));
        }
      }
    });

    return StickyTable(
      columns:         cols,
      isDark:          isDark,
      pinnedCount:     3,
      emptyMessage:    'No leads found',
      emptySubMessage: emptySubMsg,
      emptyIcon:       Icons.inbox_outlined,
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
                    '$count lead${count == 1 ? '' : 's'}',
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
      int num, LeadModel l, BuildContext context) {
    final cells = <Widget>[];
    cells.add(tCell('$num', color: text2, fontSize: 11));
    cells.add(Padding(
      padding: rowPad,
      child: Text(l.clientName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent)),
    ));
    cells.add(Padding(
      padding: rowPad,
      child: StatusBadge.forLeadStatus(l.dealClosingStatus),
    ));
    cells.add(tCell(l.date, color: text2, fontSize: 12));
    if (user.isAdmin) {
      cells.add(_salesNameCell(l.salesName));
    }
    cells.add(tCell(l.source, color: text2, fontSize: 12));
    cells.add(tCell(l.subjectsTask, color: textColor, fontSize: 12));
    cells.add(l.remarks.isEmpty ? tCell('-', color: text2) : _remarksCell(l.remarks, text2));
    cells.add(tCell(l.followupTextCall, color: text2, fontSize: 12));
    cells.add(tCell(l.whatsappNumber, fontSize: 11, mono: true));
    cells.add(tActions([
      if (user.isSales || user.isAdmin)
        tAction('Edit', AppColors.accent, () => onEdit(l)),
      if (user.isAdmin)
        tAction('Del', AppColors.red, () => onDelete(l)),
    ]));
    return cells;
  }

  Widget _remarksCell(String remarks, Color t2c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Tooltip(
        message: remarks,
        preferBelow: true,
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                remarks,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 12, color: t2c),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12, color: t2c),
          ],
        ),
      ),
    );
  }

  Widget _salesNameCell(String name) {
    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
        ),
      ]),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'In Talk':        return const Color(0xFF6366F1);
      case 'Follow Up':      return const Color(0xFFF59E0B);
      case 'Won':            return const Color(0xFF22C55E);
      case 'Lost':           return const Color(0xFFF43F5E);
      case 'Interested':     return const Color(0xFF0EA5E9);
      case 'Not Interested': return const Color(0xFF94A3B8);
      default:               return AppColors.accent;
    }
  }
}

// ─── Lead Form Dialog (unchanged from original) ────────────────────────────────
class _LeadDialog extends StatefulWidget {
  final LeadModel?       lead;
  final UserModel        user;
  final FirestoreService svc;
  final void Function(LeadModel)? onSaved;
  const _LeadDialog({
    required this.lead,
    required this.user,
    required this.svc,
    this.onSaved,
  });
  @override
  State<_LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<_LeadDialog> {
  final _cc = TextEditingController();
  final _sc = TextEditingController();
  final _rc = TextEditingController();
  final _pc = TextEditingController();
  final _fc = TextEditingController();
  final _wc = TextEditingController();

  String _date   = DateHelper.today(),
      _status = 'In Talk',
      _source = 'Instagram';
  bool   _saving = false;
  String _error  = '';

  @override
  void initState() {
    super.initState();
    if (widget.lead != null) {
      final l = widget.lead!;
      _cc.text = l.clientName;
      _sc.text = l.subjectsTask;
      _rc.text = l.remarks;
      _pc.text = l.clientProfileLink;
      _fc.text = l.followupTextCall;
      _wc.text = l.whatsappNumber;
      _date   = l.date;
      _status = AppConstants.leadStatuses.contains(l.dealClosingStatus)
          ? l.dealClosingStatus : 'In Talk';
      _source = AppConstants.leadSources.contains(l.source)
          ? l.source : 'Instagram';
    }
  }

  @override
  void dispose() {
    _cc.dispose(); _sc.dispose(); _rc.dispose();
    _pc.dispose(); _fc.dispose(); _wc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_cc.text.trim().isEmpty) {
      setState(() => _error = 'Client name is required');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      final l = LeadModel(
          id:                widget.lead?.id ?? '',
          date:              _date,
          salesId:           widget.lead?.salesId   ?? widget.user.userId,
          salesName:         widget.lead?.salesName ?? widget.user.name,
          team:              widget.lead?.team      ?? widget.user.team,
          clientName:        _cc.text.trim(),
          dealClosingStatus: _status,
          subjectsTask:      _sc.text.trim(),
          source:            _source,
          remarks:           _rc.text.trim(),
          clientProfileLink: _pc.text.trim(),
          followupTextCall:  _fc.text.trim(),
          whatsappNumber:    _wc.text.trim());

      if (widget.lead == null) {
        // ADD: get real doc id back
        final newId = await widget.svc.addLead(l);
        if (mounted) {
          Navigator.pop(context);
          final savedLead = LeadModel(
            id:                newId,
            date:              l.date,
            salesId:           l.salesId,
            salesName:         l.salesName,
            team:              l.team,
            clientName:        l.clientName,
            dealClosingStatus: l.dealClosingStatus,
            subjectsTask:      l.subjectsTask,
            source:            l.source,
            remarks:           l.remarks,
            clientProfileLink: l.clientProfileLink,
            followupTextCall:  l.followupTextCall,
            whatsappNumber:    l.whatsappNumber,
          );
          widget.onSaved?.call(savedLead);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Lead added!'),
              backgroundColor: AppColors.green));
        }
      } else {
        await widget.svc.updateLead(widget.lead!.id, l.toMap());
        if (mounted) {
          Navigator.pop(context);
          // EDIT: use existing id with updated fields
          final updatedLead = widget.lead!.copyWith(
            clientName:        _cc.text.trim(),
            dealClosingStatus: _status,
            subjectsTask:      _sc.text.trim(),
            source:            _source,
            remarks:           _rc.text.trim(),
            clientProfileLink: _pc.text.trim(),
            followupTextCall:  _fc.text.trim(),
            whatsappNumber:    _wc.text.trim(),
          );
          widget.onSaved?.call(updatedLead);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Lead updated!'),
              backgroundColor: AppColors.green));
        }
      }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final textColor = isDark ? AppColors.darkText     : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2    : AppColors.lightText2;
    final s2        = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final screenW   = MediaQuery.of(context).size.width;
    final isMobile  = screenW < 600;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: isMobile ? double.infinity : 620,
        constraints: BoxConstraints(
          maxHeight: isMobile
              ? MediaQuery.of(context).size.height * 0.88
              : 600,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 10, 14),
            child: Row(children: [
              Text(widget.lead == null ? 'Add Lead' : 'Edit Lead',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
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
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _f('Client Name *', _cc, textColor, text2,
                          w: double.infinity),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _d(
                            'Status', AppConstants.leadStatuses, _status,
                                (v) => setState(() => _status = v!),
                            textColor, text2, s2)),
                        const SizedBox(width: 12),
                        Expanded(child: _d(
                            'Source', AppConstants.leadSources, _source,
                                (v) => setState(() => _source = v!),
                            textColor, text2, s2)),
                      ]),
                      const SizedBox(height: 14),
                      _f('Subject / Task', _sc, textColor, text2,
                          w: double.infinity),
                      const SizedBox(height: 14),
                      _f('WhatsApp Number', _wc, textColor, text2,
                          w: double.infinity),
                      const SizedBox(height: 14),
                      _f('Client Profile Link', _pc, textColor, text2,
                          w: double.infinity),
                      const SizedBox(height: 14),
                      _f('Follow Up', _fc, textColor, text2,
                          w: double.infinity),
                      const SizedBox(height: 14),
                      _f('Remarks', _rc, textColor, text2,
                          w: double.infinity, lines: 3),
                    ],
                  )
                else
                  Wrap(spacing: 16, runSpacing: 16, children: [
                    _f('Client Name *', _cc, textColor, text2, w: 270),
                    _d('Status', AppConstants.leadStatuses, _status,
                            (v) => setState(() => _status = v!),
                        textColor, text2, s2),
                    _d('Source', AppConstants.leadSources, _source,
                            (v) => setState(() => _source = v!),
                        textColor, text2, s2),
                    _f('Subject / Task', _sc, textColor, text2, w: 270),
                    _f('WhatsApp Number', _wc, textColor, text2),
                    _f('Client Profile Link', _pc, textColor, text2, w: 270),
                    _f('Follow Up', _fc, textColor, text2, w: 270),
                    _f('Remarks', _rc, textColor, text2, w: 560, lines: 3),
                  ]),
              ]),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                  child: _saving
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : Text(
                      widget.lead == null
                          ? 'Save Lead' : 'Update Lead',
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

  Widget _f(String label, TextEditingController ctrl,
      Color tc, Color t2,
      {double w = 180, int lines = 1}) =>
      SizedBox(
        width: w == double.infinity ? double.infinity : w,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
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
                        horizontal: 12, vertical: 10)),
              ),
            ]),
      );

  Widget _d(String label, List<String> items, String val,
      ValueChanged<String?> onChange,
      Color tc, Color t2, Color s2) =>
      SizedBox(
        width: 180,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
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