// lib/screens/tasks/tasks_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/sticky_table.dart';
import '../../widgets/status_badge.dart';

class TasksScreen extends StatefulWidget {
  final bool myTasksOnly;
  const TasksScreen({super.key, this.myTasksOnly = false});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _svc        = FirestoreService();
  final _searchCtrl = TextEditingController();

  String _searchQuery  = '';
  String _filterMonth  = _currentMonthKey();
  String _filterStatus = 'All';
  String _quickDate    = '';

  static String _currentMonthKey() {
    final now = DateTime.now();
    final m   = now.month.toString().padLeft(2, '0');
    return '${now.year}-$m';
  }

  // ── Admin sales filter ───────────────────────────────────────
  String _filterSalesId = 'all';
  List<UserModel> _salesUsers = [];

  // ── Group by status ──────────────────────────────────────────
  bool _groupByStatus = false;
  final Set<String> _collapsed = {};

  // ── PAGINATION STATE ─────────────────────────────────────────
  List<TaskModel> _tasks      = [];
  bool   _loading             = true;
  int    _currentPage         = 1;
  bool   _hasMore             = false;
  final List<DocumentSnapshot?> _cursorStack = [null];

  // Stream for summary bar ONLY (lightweight, always real-time)
//  late Stream<List<TaskModel>> _tasksStream;

  // ── Column definitions ────────────────────────────────────────
  static const _cols = [
    TableCol('Task ID',   130),
    TableCol('Sales ID',  110),
    TableCol('Date',      100),
    TableCol('Client',    135),
    TableCol('Subject',   165),
    TableCol('Type',      105),
    TableCol('Words',      75),
    TableCol('Deadline',  130),
    TableCol('Priority',   85),
    TableCol('Writer',    115),
    TableCol('Status',    150),
    TableCol('Actions',   290),
  ];

  bool _streamInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamInitialized) {
      _streamInitialized = true;
      final user = context.read<AuthProvider>().currentUser!;
      // Stream is used ONLY for the summary bar — stays lightweight
 //     _tasksStream = _svc.tasksStream(user);
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSalesUsers());
      _fetchPage(); // load first page
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadSalesUsers() async {
    final user = context.read<AuthProvider>().currentUser!;
    if (!user.isAdmin) return;
    final all = await _svc.getAllUsers();
    if (!mounted) return;
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _salesUsers = all.where((u) => u.isSales).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Pagination ────────────────────────────────────────────────
  Future<void> _fetchPage() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final user   = context.read<AuthProvider>().currentUser!;
    final cursor = _cursorStack[_currentPage - 1];

    // Month filter applied client-side in service — no composite index needed
    final result = await _svc.getTasksPaginated(
      user: user,
      filterMonth: _quickDate.isEmpty ? _filterMonth : '',
      startAfter: cursor,
      // ADD THIS LINE ↓
      pageIndex: _currentPage - 1, // add this one
    );

    if (!mounted) return;

    if (_cursorStack.length <= _currentPage) {
      _cursorStack.add(result.lastDoc);
    }

    setState(() {
      _tasks   = result.items;
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

  void _resetPagination() {
    _currentPage = 1;
    _cursorStack
      ..clear()
      ..add(null);
    _fetchPage();
  }

  // ── Quick date helper ─────────────────────────────────────────
  bool _matchesQuickDate(String taskDate) {
    if (_quickDate.isEmpty) return true;
    final now = DateTime.now();
    DateTime? d;
    try {
      d = DateTime.parse(taskDate);
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
          _filterStatus != 'All' ||
          _quickDate.isNotEmpty ||
          _filterSalesId != 'all' ||
          _searchQuery.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _filterMonth   = _currentMonthKey();
      _filterStatus  = 'All';
      _quickDate     = '';
      _filterSalesId = 'all';
      _searchQuery   = '';
      _searchCtrl.clear();
    });
    _resetPagination();
  }

  // ── Apply client-side filters ─────────────────────────────────
  // Month is already applied by Firestore (unless quickDate is active)
  List<TaskModel> _applyFilters(List<TaskModel> tasks, UserModel user) {
    var filtered = tasks;

    if (user.isAdmin && _filterSalesId != 'all') {
      filtered = filtered.where((t) => t.salesId == _filterSalesId).toList();
    }

    if (_quickDate.isNotEmpty) {
      filtered = filtered.where((t) => _matchesQuickDate(t.dateAssigned)).toList();
    }

    if (_filterStatus != 'All') {
      filtered = filtered.where((t) => t.status == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) =>
          '${t.clientName} ${t.subject} '
              '${t.writerName} ${t.taskId} '
              '${t.salesTaskId} ${t.salesName}'
              .toLowerCase()
              .contains(_searchQuery)).toList();
    }

    return filtered;
  }

  String _quickDateLabel(String key) {
    switch (key) {
      case 'today': return 'Today';
      case 'week':  return 'This Week';
      case 'month': return 'This Month';
      default:      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = context.watch<AuthProvider>().currentUser!;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg     : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2   : AppColors.lightText2;

    final title    = widget.myTasksOnly ? 'My Tasks'
        : (user.isWriter ? 'My Tasks' : 'Writer Tasks');
    final subtitle = widget.myTasksOnly
        ? 'Tasks assigned to writers from your deals'
        : (user.isWriter
        ? 'Tasks assigned to you'
        : 'Track all writer task assignments');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: isMobile
                  ? _buildHeaderMobile(context, user, surface, border, textColor, text2, title, subtitle)
                  : _buildHeaderDesktop(context, user, surface, border, textColor, text2, title, subtitle),
            ),

            // ── Summary bar (from stream — always real-time) ───────
      /**      StreamBuilder<List<TaskModel>>(
              stream: _tasksStream,
              builder: (ctx, snap) {
                final all = snap.data ?? [];
                final filtered = _applyFilters(all, user);
                return _TaskSummaryBar(tasks: filtered, bg: bg, text2: text2);
              },
          ),      */
            _TaskSummaryBar(
              tasks: _applyFilters(_tasks, user),
              bg: bg,
              text2: text2,
            ),

            // ── Search bar ────────────────────────────────────────
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: TextStyle(fontSize: 13, color: textColor),
                  decoration: _searchDeco(text2, surface, border),
                ),
              ),
            ),

            // ── Filters ───────────────────────────────────────────
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: isMobile
                  ? _buildFiltersMobile(user, surface, border, textColor, text2)
                  : _buildFiltersDesktop(user, surface, border, textColor, text2),
            ),

            // ── Table ─────────────────────────────────────────────
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
                    Expanded(child: _buildTable(user, isDark, textColor, text2, surface, border)),

                    // ── Pagination bar ──────────────────────────
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
      UserModel user, bool isDark, Color textColor, Color text2,
      Color surface, Color border) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final tasks = _applyFilters(_tasks, user);

    if (_groupByStatus) {
      return _GroupedTaskTable(
        tasks:       tasks,
        cols:        _cols,
        user:        user,
        isDark:      isDark,
        collapsed:   _collapsed,
        surface:     surface,
        border:      border,
        textColor:   textColor,
        text2:       text2,
        onToggle:    (s) => setState(() {
          _collapsed.contains(s)
              ? _collapsed.remove(s)
              : _collapsed.add(s);
        }),
        onEdit:      (t) => _openEditTaskDialog(context, t, user),
        onDelete:    (t) => _confirmDelete(context, t),
        onSubmit:    (t) => _openSubmitDialog(context, t),
        onEditFile:  (t) => _openEditFileDialog(context, t),
        onDoAction:  (t, a) => _doAction(context, t, a),
        onComment:   (t) => _openCommentsDialog(context, t, user),
        onOpenUrl:   _openUrl,
        emptySubMsg: _hasActiveFilters
            ? 'Try clearing some filters'
            : 'Tasks appear after deals are assigned to writers',
      );
    }

    // Flat table
    return _FlatTaskTable(
      tasks:      tasks,
      cols:       _cols,
      user:       user,
      isDark:     isDark,
      border:     border,
      textColor:  textColor,
      text2:      text2,
      onEdit:     (t) => _openEditTaskDialog(context, t, user),
      onDelete:   (t) => _confirmDelete(context, t),
      onSubmit:   (t) => _openSubmitDialog(context, t),
      onEditFile: (t) => _openEditFileDialog(context, t),
      onDoAction: (t, a) => _doAction(context, t, a),
      onComment:  (t) => _openCommentsDialog(context, t, user),
      onOpenUrl:  _openUrl,
      emptySubMsg: _hasActiveFilters
          ? 'Try clearing some filters'
          : 'Tasks appear after deals are assigned to writers',
    );
  }

  // ── Desktop header ────────────────────────────────────────────
  Widget _buildHeaderDesktop(
      BuildContext context, UserModel user,
      Color surface, Color border, Color textColor, Color text2,
      String title, String subtitle) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w700, color: textColor)),
              if (_filterMonth.isNotEmpty || _quickDate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  _quickDate.isNotEmpty
                      ? '· ${_quickDateLabel(_quickDate)}'
                      : '· $_filterMonth',
                  style: TextStyle(fontSize: 13, color: text2,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ]),
            Text(subtitle, style: TextStyle(fontSize: 12, color: text2)),
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
    ]);
  }

  // ── Mobile header ─────────────────────────────────────────────
  Widget _buildHeaderMobile(
      BuildContext context, UserModel user,
      Color surface, Color border, Color textColor, Color text2,
      String title, String subtitle) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: textColor)),
              if (_filterMonth.isNotEmpty || _quickDate.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _quickDate.isNotEmpty
                        ? '· ${_quickDateLabel(_quickDate)}'
                        : '· $_filterMonth',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: text2,
                        fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ]),
            Text(subtitle, style: TextStyle(fontSize: 11, color: text2)),
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
                ? AppColors.accent.withOpacity(0.10) : surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _groupByStatus
                    ? AppColors.accent.withOpacity(0.35) : border),
          ),
          child: Icon(Icons.table_rows_outlined,
              size: 16,
              color: _groupByStatus ? AppColors.accent : text2),
        ),
      ),
    ]);
  }

  // ── Desktop filters ───────────────────────────────────────────
  Widget _buildFiltersDesktop(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _filterChips(user, surface, border, textColor, text2),
    );
  }

  // ── Mobile filters ────────────────────────────────────────────
  Widget _buildFiltersMobile(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _quickChip('Today',      'today', surface, border, text2),
            const SizedBox(width: 6),
            _quickChip('This Week',  'week',  surface, border, text2),
            const SizedBox(width: 6),
            _quickChip('This Month', 'month', surface, border, text2),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _monthPicker(surface, border, textColor, text2),
            const SizedBox(width: 6),
            _statusPicker(surface, border, textColor, text2),
            if (user.isAdmin && _salesUsers.isNotEmpty) ...[
              const SizedBox(width: 6),
              _salesPersonPicker(surface, border, textColor, text2),
            ],
            if (_hasActiveFilters) ...[
              const SizedBox(width: 6),
              _clearChip('Clear All', _clearAllFilters,
                  AppColors.accent.withOpacity(0.1),
                  AppColors.accent.withOpacity(0.4),
                  AppColors.accent),
            ],
          ]),
        ),
      ],
    );
  }

  // ── Shared filter chips ───────────────────────────────────────
  List<Widget> _filterChips(
      UserModel user,
      Color surface, Color border, Color textColor, Color text2) {
    return [
      _quickChip('Today',      'today', surface, border, text2),
      _quickChip('This Week',  'week',  surface, border, text2),
      _quickChip('This Month', 'month', surface, border, text2),
      _monthPicker(surface, border, textColor, text2),
      _statusPicker(surface, border, textColor, text2),
      if (user.isAdmin && _salesUsers.isNotEmpty)
        _salesPersonPicker(surface, border, textColor, text2),
      if (_filterMonth != _currentMonthKey() && _filterMonth.isNotEmpty)
        _clearChip('✕ $_filterMonth',
                () => setState(() => _filterMonth = _currentMonthKey()),
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
              color: active ? AppColors.accent.withOpacity(0.35) : border),
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
  Widget _quickChip(String label, String key,
      Color surface, Color border, Color t2) {
    final isActive = _quickDate == key;
    return GestureDetector(
      onTap: () => setState(() {
        _quickDate   = isActive ? '' : key;
        _filterMonth = '';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.12) : surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive ? AppColors.accent.withOpacity(0.45) : border),
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
  Widget _monthPicker(Color surface, Color border, Color tc, Color t2) {
    final months = DateHelper.getMonthList();
    return _dropdownBox(
      surface: surface, border: border,
      active: _filterMonth.isNotEmpty,
      child: DropdownButton<String>(
        value: _filterMonth.isEmpty ? null : _filterMonth,
        hint: Text('All Months', style: TextStyle(fontSize: 12, color: t2)),
        items: months.map((m) => DropdownMenuItem(value: m,
            child: Text(m, style: TextStyle(fontSize: 12, color: tc)))).toList(),
        onChanged: (v) => setState(() {
          _filterMonth = v ?? '';
          _quickDate   = '';
        }),
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true, underline: const SizedBox(),
      ),
    );
  }

  // ── Status picker ─────────────────────────────────────────────
  Widget _statusPicker(Color surface, Color border, Color tc, Color t2) {
    const statuses = [
      'All', 'Pending', 'In Progress', 'Completed',
      'Reviewed', 'Forwarded to Sales',
    ];
    return _dropdownBox(
      surface: surface, border: border,
      active: _filterStatus != 'All',
      child: DropdownButton<String>(
        value: _filterStatus,
        items: statuses.map((s) => DropdownMenuItem(value: s,
            child: Text(s, style: TextStyle(fontSize: 12, color: tc)))).toList(),
        onChanged: (v) => setState(() => _filterStatus = v ?? 'All'),
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true, underline: const SizedBox(),
      ),
    );
  }

  // ── Sales person picker ───────────────────────────────────────
  Widget _salesPersonPicker(Color surface, Color border, Color tc, Color t2) {
    return _dropdownBox(
      surface: surface, border: border,
      active: _filterSalesId != 'all',
      minWidth: 160,
      child: DropdownButton<String>(
        value: _filterSalesId,
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text('All Sales People', style: TextStyle(fontSize: 12, color: tc)),
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
                    style: const TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${u.name} (@${u.username})',
                  style: TextStyle(fontSize: 12, color: tc)),
            ]),
          )),
        ],
        onChanged: (v) => setState(() => _filterSalesId = v ?? 'all'),
        dropdownColor: surface,
        style: TextStyle(color: tc, fontSize: 12),
        isDense: true, underline: const SizedBox(),
      ),
    );
  }

  // ── Dropdown box wrapper ──────────────────────────────────────
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
        color: active ? AppColors.accent.withOpacity(0.08) : surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: active ? AppColors.accent.withOpacity(0.4) : border),
      ),
      child: child,
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
            color: bg, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: bd)),
        child: Text(label, style: TextStyle(fontSize: 12, color: tc)),
      ),
    );
  }

  // ── Search decoration ─────────────────────────────────────────
  InputDecoration _searchDeco(Color t2, Color surface, Color border) =>
      InputDecoration(
        hintText: 'Search client, subject, writer...',
        hintStyle: TextStyle(color: t2),
        filled: true, fillColor: surface,
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

  // ── Dialogs ───────────────────────────────────────────────────
  void _openEditTaskDialog(BuildContext context, TaskModel task,
      UserModel currentUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditTaskDialog(
        task: task,
        currentUser: currentUser,
        svc: _svc,
        onSaved: (updatedTask) {
          setState(() {
            final idx = _tasks.indexWhere(
                    (t) => t.taskId == updatedTask.taskId);
            if (idx != -1) _tasks[idx] = updatedTask;
          });
        },
      ),
    );
  }

  void _openSubmitDialog(BuildContext context, TaskModel task) {
    final ctrl  = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: const Text('Submit Completed Task'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste your Google Drive file link:',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: ctrl,
                  decoration: const InputDecoration(
                      hintText: 'https://drive.google.com/...')),
              const SizedBox(height: 6),
              const Text('Set link to "Anyone with the link can view".',
                  style: TextStyle(fontSize: 11, color: AppColors.darkText3)),
            ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final fileLink = ctrl.text.trim();
              await _svc.submitTaskCompletion(task.taskId, fileLink);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                setState(() {
                  final idx = _tasks.indexWhere(
                          (t) => t.taskId == task.taskId);
                  if (idx != -1) {
                    _tasks[idx] = _tasks[idx].copyWith(
                      status:        'Completed',
                      fileLink:      fileLink,
                      completedDate: DateTime.now().toIso8601String(),
                    );
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ Task submitted! Team leader will review.'),
                  backgroundColor: AppColors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Submit ✓', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEditFileDialog(BuildContext context, TaskModel task) {
    final ctrl  = TextEditingController(text: task.fileLink);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: const Text('Update File Link'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(
                hintText: 'https://drive.google.com/...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final newLink = ctrl.text.trim();
              await _svc.updateTask(task.taskId, {'fileLink': newLink});
              if (ctx.mounted) {
                Navigator.pop(ctx);
                // ── update local list instantly ✅
                setState(() {
                  final idx = _tasks.indexWhere(
                          (t) => t.taskId == task.taskId);
                  if (idx != -1) {
                    _tasks[idx] = _tasks[idx].copyWith(
                      fileLink: newLink,
                    );
                  }
                });
              }
            },
            child: const Text('Update',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _doAction(BuildContext context, TaskModel task, String action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(action == 'review' ? '👁 Review Task?' : '📨 Forward to Sales?'),
        content: Text(action == 'review'
            ? 'Mark this task as Reviewed?'
            : 'Forward this completed task to the sales person?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = context.read<AuthProvider>().currentUser!;
              await _svc.reviewTask(task.taskId, action, user.name);
              setState(() {
                final idx = _tasks.indexWhere(
                        (t) => t.taskId == task.taskId);
                if (idx != -1) {
                  _tasks[idx] = _tasks[idx].copyWith(
                    status: action == 'review'
                        ? 'Reviewed'
                        : 'Forwarded to Sales',
                  );
                }
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(action == 'review'
                      ? '✅ Task reviewed!'
                      : '📨 Forwarded to sales!'),
                  backgroundColor: AppColors.green,
                ));
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TaskModel task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: const Text('Delete Task?'),
        content: Text('Delete "${task.subject}" for ${task.clientName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _svc.deleteTask(task.taskId, task.dealId);
              setState(() =>
                  _tasks.removeWhere((t) => t.taskId == task.taskId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Task deleted'),
                        backgroundColor: AppColors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openCommentsDialog(BuildContext context, TaskModel task, UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CommentsDialog(task: task, user: user, svc: _svc),
    );
  }

  Future<void> _openUrl(String rawUrl) async {
    if (rawUrl.isEmpty) return;
    String url = rawUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Cannot open URL: $rawUrl — $e');
    }
  }
}

// ─── Task Summary Bar ─────────────────────────────────────────────────────────
class _TaskSummaryBar extends StatelessWidget {
  final List<TaskModel> tasks;
  final Color bg;
  final Color text2;
  const _TaskSummaryBar({required this.tasks, required this.bg, required this.text2});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final t in tasks) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }

    final pills = [
      _PillData('${tasks.length} tasks',                          null,                      const Color(0xFF6B7280), false),
      _PillData('${counts['Pending'] ?? 0} Pending',              const Color(0xFFF59E0B),   const Color(0xFF92400E), true),
      _PillData('${counts['In Progress'] ?? 0} In Progress',      const Color(0xFF6366F1),   const Color(0xFF4338CA), true),
      _PillData('${counts['Completed'] ?? 0} Completed',          const Color(0xFF22C55E),   const Color(0xFF166534), true),
      _PillData('${counts['Reviewed'] ?? 0} Reviewed',            const Color(0xFF0EA5E9),   const Color(0xFF0369A1), true),
      _PillData('${counts['Forwarded to Sales'] ?? 0} Forwarded', const Color(0xFF8B5CF6),   const Color(0xFF6D28D9), true),
    ];

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8, runSpacing: 6,
        children: pills.map((p) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (p.dot != null) ...[
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: p.dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(p.label,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: p.textColor)),
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

// ─── Action Button Helpers ────────────────────────────────────────────────────
List<Widget> buildTaskActionButtons({
  required BuildContext context,
  required TaskModel t,
  required UserModel user,
  required void Function(TaskModel) onEdit,
  required void Function(TaskModel) onDelete,
  required void Function(TaskModel) onSubmit,
  required void Function(TaskModel) onEditFile,
  required void Function(TaskModel, String) onDoAction,
  required void Function(TaskModel) onComment,
  required void Function(String) onOpenUrl,
}) {
  final btns = <Widget>[];

  if (user.isSales || user.isAdmin) {
    btns.add(tAction('Edit', AppColors.accent, () => onEdit(t),
        icon: Icons.edit_outlined));
  }

  if (user.isWriter) {
    if (!t.isCompleted) {
      btns.add(tAction('Submit', AppColors.green, () => onSubmit(t),
          icon: Icons.upload_outlined));
    }
    if (t.fileLink.isNotEmpty) {
      btns.add(tAction('Edit File', AppColors.cyan, () => onEditFile(t),
          icon: Icons.edit_outlined));
    }
  }

  if (user.isTeamLeader || user.isAdmin) {
    if (t.status == 'Completed') {
      btns.add(tAction('Review', AppColors.purple, () => onDoAction(t, 'review'),
          icon: Icons.visibility_outlined));
    }
    if (t.status == 'Reviewed') {
      btns.add(tAction('Forward', AppColors.yellow, () => onDoAction(t, 'forward'),
          icon: Icons.forward_outlined));
    }
  }

  if (user.isAdmin) {
    btns.add(tAction('Del', AppColors.red, () => onDelete(t),
        icon: Icons.delete_outline));
  }

  if (t.salesFileLink.isNotEmpty) {
    btns.add(_urlActionBtn('📁 Brief', t.salesFileLink, AppColors.accent, onOpenUrl));
  }
  if (t.fileLink.isNotEmpty) {
    btns.add(_urlActionBtn('📄 File', t.fileLink, AppColors.green, onOpenUrl));
  }

  btns.add(_commentActionBtn(t, onComment));

  return btns;
}

Widget _urlActionBtn(String label, String url, Color color,
    void Function(String) onOpen) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onOpen(url),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5,
            fontWeight: FontWeight.w700, color: color)),
      ),
    ),
  );
}

Widget _commentActionBtn(TaskModel t, void Function(TaskModel) onComment) {
  final count = t.comments.length;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onComment(t),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.accent),
          const SizedBox(width: 3),
          const Text('💬', style: TextStyle(fontSize: 11)),
          if (count > 0) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.red, borderRadius: BorderRadius.circular(8)),
              child: Text('+$count', style: const TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ]),
      ),
    ),
  );
}


// ─── UNCHANGED CLASSES FROM ORIGINAL ────────────────────────────────────────
// ─── Grouped Task Table ───────────────────────────────────────────────────────
class _GroupedTaskTable extends StatelessWidget {
  final List<TaskModel>      tasks;
  final List<TableCol>       cols;
  final UserModel            user;
  final bool                 isDark;
  final Set<String>          collapsed;
  final Color                surface;
  final Color                border;
  final Color                textColor;
  final Color                text2;
  final void Function(String)       onToggle;
  final void Function(TaskModel)    onEdit;
  final void Function(TaskModel)    onDelete;
  final void Function(TaskModel)    onSubmit;
  final void Function(TaskModel)    onEditFile;
  final void Function(TaskModel, String) onDoAction;
  final void Function(TaskModel)    onComment;
  final void Function(String)       onOpenUrl;
  final String               emptySubMsg;

  const _GroupedTaskTable({
    required this.tasks,
    required this.cols,
    required this.user,
    required this.isDark,
    required this.collapsed,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmit,
    required this.onEditFile,
    required this.onDoAction,
    required this.onComment,
    required this.onOpenUrl,
    required this.emptySubMsg,
  });

  static const _statusOrder = [
    'Pending', 'In Progress', 'Completed', 'Reviewed', 'Forwarded to Sales',
  ];

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_outlined, size: 52, color: text2),
            const SizedBox(height: 12),
            Text('No tasks found',
                style: TextStyle(fontSize: 15, color: text2,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(emptySubMsg,
                style: TextStyle(fontSize: 12,
                    color: isDark ? AppColors.darkText3 : AppColors.lightText3)),
          ],
        ),
      );
    }

    final grouped = <String, List<TaskModel>>{};
    for (final s in _statusOrder) {
      final g = tasks.where((t) => t.status == s).toList();
      if (g.isNotEmpty) grouped[s] = g;
    }
    for (final t in tasks) {
      if (!_statusOrder.contains(t.status)) {
        grouped.putIfAbsent(t.status, () => []).add(t);
      }
    }

    final allRows = <List<Widget>>[];

    grouped.forEach((status, groupTasks) {
      allRows.add(_buildGroupHeaderRow(status, groupTasks.length));
      if (!collapsed.contains(status)) {
        for (int i = 0; i < groupTasks.length; i++) {
          allRows.add(_buildDataRow(i + 1, groupTasks[i], context));
        }
      }
    });

    return StickyTable(
      columns:         cols,
      isDark:          isDark,
      pinnedCount:     3,
      emptyMessage:    'No tasks found',
      emptySubMessage: emptySubMsg,
      emptyIcon:       Icons.task_outlined,
      rows:            allRows,
    );
  }

  List<Widget> _buildGroupHeaderRow(String status, int count) {
    final color = _statusColor(status);
    final isOpen = !collapsed.contains(status);
    final rowBg  = isDark ? color.withOpacity(0.07) : color.withOpacity(0.05);

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
          minWidth: 0, maxWidth: double.infinity,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$count task${count == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: color.withOpacity(0.85))),
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

  List<Widget> _buildDataRow(int num, TaskModel t, BuildContext context) {
    final isOverdue = t.isOverdue && !t.isCompleted;

    return [
      tCell(t.taskId, color: AppColors.accent, mono: true, fontSize: 11),
      tCell(t.salesTaskId.isEmpty ? '-' : t.salesTaskId,
          color: AppColors.yellow, mono: true, fontSize: 11),
      tCell(t.dateAssigned, color: text2, fontSize: 12),
      tCell(t.clientName, color: textColor, fontSize: 13, bold: true),
      tCell(t.subject, color: textColor, fontSize: 12),
      tCell(t.assignmentType, color: text2, fontSize: 12),
      tCell(t.wordCount, color: text2, mono: true, fontSize: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: DeadlineBadge(dateStr: t.deadline, daysLeft: t.daysLeft),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: PriorityBadge(priority: t.priority),
      ),
      tCell(t.writerName, color: text2, fontSize: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: StatusBadge.forTaskStatus(t.status),
      ),
      tActions(buildTaskActionButtons(
        context:    context,
        t:          t,
        user:       user,
        onEdit:     onEdit,
        onDelete:   onDelete,
        onSubmit:   onSubmit,
        onEditFile: onEditFile,
        onDoAction: onDoAction,
        onComment:  onComment,
        onOpenUrl:  onOpenUrl,
      )),
    ];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':            return const Color(0xFFF59E0B);
      case 'In Progress':        return const Color(0xFF6366F1);
      case 'Completed':          return const Color(0xFF22C55E);
      case 'Reviewed':           return const Color(0xFF0EA5E9);
      case 'Forwarded to Sales': return const Color(0xFF8B5CF6);
      default:                   return AppColors.accent;
    }
  }
}

// ─── Flat Task Table ──────────────────────────────────────────────────────────
class _FlatTaskTable extends StatelessWidget {
  final List<TaskModel>      tasks;
  final List<TableCol>       cols;
  final UserModel            user;
  final bool                 isDark;
  final Color                border;
  final Color                textColor;
  final Color                text2;
  final void Function(TaskModel)    onEdit;
  final void Function(TaskModel)    onDelete;
  final void Function(TaskModel)    onSubmit;
  final void Function(TaskModel)    onEditFile;
  final void Function(TaskModel, String) onDoAction;
  final void Function(TaskModel)    onComment;
  final void Function(String)       onOpenUrl;
  final String               emptySubMsg;

  const _FlatTaskTable({
    required this.tasks,
    required this.cols,
    required this.user,
    required this.isDark,
    required this.border,
    required this.textColor,
    required this.text2,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmit,
    required this.onEditFile,
    required this.onDoAction,
    required this.onComment,
    required this.onOpenUrl,
    required this.emptySubMsg,
  });

  @override
  Widget build(BuildContext context) {
    final rows = tasks.asMap().entries.map((entry) {
      final t = entry.value;
      return [
        tCell(t.taskId, color: AppColors.accent, mono: true, fontSize: 11),
        tCell(t.salesTaskId.isEmpty ? '-' : t.salesTaskId,
            color: AppColors.yellow, mono: true, fontSize: 11),
        tCell(t.dateAssigned, color: text2, fontSize: 12),
        tCell(t.clientName, color: textColor, fontSize: 13, bold: true),
        tCell(t.subject, color: textColor, fontSize: 12),
        tCell(t.assignmentType, color: text2, fontSize: 12),
        tCell(t.wordCount, color: text2, mono: true, fontSize: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: DeadlineBadge(dateStr: t.deadline, daysLeft: t.daysLeft),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: PriorityBadge(priority: t.priority),
        ),
        tCell(t.writerName, color: text2, fontSize: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: StatusBadge.forTaskStatus(t.status),
        ),
        tActions(buildTaskActionButtons(
          context:    context,
          t:          t,
          user:       user,
          onEdit:     onEdit,
          onDelete:   onDelete,
          onSubmit:   onSubmit,
          onEditFile: onEditFile,
          onDoAction: onDoAction,
          onComment:  onComment,
          onOpenUrl:  onOpenUrl,
        )),
      ];
    }).toList();

    return StickyTable(
      columns:         cols,
      isDark:          isDark,
      pinnedCount:     3,
      emptyMessage:    'No tasks found',
      emptySubMessage: emptySubMsg,
      emptyIcon:       Icons.task_outlined,
      rows:            rows,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EDIT TASK DIALOG  (unchanged from original)
// ════════════════════════════════════════════════════════════════
class _EditTaskDialog extends StatefulWidget {
  final TaskModel task;
  final UserModel currentUser;
  final FirestoreService svc;
  final void Function(TaskModel)? onSaved;
  const _EditTaskDialog({
    required this.task,
    required this.currentUser,
    required this.svc,
    this.onSaved,
  });
  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  final _subjectCtrl   = TextEditingController();
  final _wordsCtrl     = TextEditingController();
  final _notesCtrl     = TextEditingController();
  final _salesTaskCtrl = TextEditingController();

  String _assignmentType = 'Essay';
  String _priority       = 'Medium';
  String _deadline       = '';
  String _writerId       = '';
  String _writerName     = '';

  List<UserModel> _writers = [];
  bool _loadingWriters = true;
  bool _saving         = false;
  String _error        = '';

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text   = widget.task.subject;
    _wordsCtrl.text     = widget.task.wordCount;
    _notesCtrl.text     = widget.task.notes;
    _salesTaskCtrl.text = widget.task.salesTaskId;
    _deadline           = widget.task.deadline;
    _writerId           = widget.task.writerId;
    _writerName         = widget.task.writerName;

    _assignmentType =
    AppConstants.assignmentTypes.contains(widget.task.assignmentType)
        ? widget.task.assignmentType : 'Essay';

    _priority = AppConstants.priorities.contains(widget.task.priority)
        ? widget.task.priority : 'Medium';

    _loadWriters();
  }

  Future<void> _loadWriters() async {
    final writers = await widget.svc.getWriters();
    if (mounted) {
      setState(() { _writers = writers; _loadingWriters = false; });
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _wordsCtrl.dispose();
    _notesCtrl.dispose();
    _salesTaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Subject is required'); return;
    }
    if (_deadline.isEmpty) {
      setState(() => _error = 'Deadline is required'); return;
    }
    if (_writerId.isEmpty) {
      setState(() => _error = 'Please select a writer'); return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      await widget.svc.updateTask(widget.task.taskId, {
        'subject':        _subjectCtrl.text.trim(),
        'assignmentType': _assignmentType,
        'wordCount':      _wordsCtrl.text.trim(),
        'deadline':       _deadline,
        'priority':       _priority,
        'writerId':       _writerId,
        'writerName':     _writerName,
        'notes':          _notesCtrl.text.trim(),
        'salesTaskId':    _salesTaskCtrl.text.trim(),
      });
      // Sync word count back to Deals Closed add this if code ok
      if (widget.task.dealId.isNotEmpty) {
        await widget.svc.updateDeal(widget.task.dealId, {
          'wordCount': _wordsCtrl.text.trim(),
          'writerAssigned': _writerName,
          'salesTaskId':    _salesTaskCtrl.text.trim(),
        });
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call(widget.task.copyWith(
          subject:        _subjectCtrl.text.trim(),
          assignmentType: _assignmentType,
          wordCount:      _wordsCtrl.text.trim(),
          deadline:       _deadline,
          priority:       _priority,
          writerId:       _writerId,
          writerName:     _writerName,
          notes:          _notesCtrl.text.trim(),
          salesTaskId:    _salesTaskCtrl.text.trim(),
        ));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Task updated successfully!'),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final surface2  = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText      : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2     : AppColors.lightText2;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
            child: Row(children: [
              const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Task', style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: textColor)),
                  Text('Client: ${widget.task.clientName}',
                      style: TextStyle(fontSize: 12, color: text2)),
                ],
              )),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loadingWriters
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.tag, size: 14, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Task ID: ${widget.task.taskId}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace',
                            color: AppColors.accent, fontWeight: FontWeight.w700)),
                  ]),
                ),

                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.redSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 15, color: AppColors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error,
                          style: const TextStyle(fontSize: 12, color: AppColors.red))),
                    ]),
                  ),

                Wrap(spacing: 16, runSpacing: 16, children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lbl('Select Writer *', text2),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: _writerId.isEmpty ? null : _writerId,
                          hint: Text('Select writer',
                              style: TextStyle(fontSize: 13, color: text2)),
                          items: _writers.map((w) => DropdownMenuItem(
                            value: w.userId,
                            child: Text('${w.name} (@${w.username})',
                                style: TextStyle(fontSize: 13, color: textColor)),
                          )).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _writerId = v;
                              _writerName = _writers
                                  .firstWhere((w) => w.userId == v).name;
                            });
                          },
                          dropdownColor: surface2,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10)),
                        ),
                      ],
                    ),
                  ),

                  _field('Subject *', _subjectCtrl, textColor, text2, w: 280),

                  _dropdown('Assignment Type', AppConstants.assignmentTypes,
                      _assignmentType,
                          (v) => setState(() => _assignmentType = v!),
                      textColor, text2, surface2),

                  _dropdown('Priority', AppConstants.priorities,
                      _priority,
                          (v) => setState(() => _priority = v!),
                      textColor, text2, surface2),

                  _field('Word Count', _wordsCtrl, textColor, text2,
                      w: 130, kb: TextInputType.number),

                  SizedBox(
                    width: 180,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lbl('Deadline *', text2),
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () async {
                            final init = DateHelper.parse(_deadline) ??
                                DateTime.now().add(const Duration(days: 7));
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: init,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _deadline = DateHelper.format(picked));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: border),
                            ),
                            child: Row(children: [
                              Icon(Icons.calendar_today, size: 14, color: text2),
                              const SizedBox(width: 8),
                              Text(
                                _deadline.isEmpty ? 'Pick a date' : _deadline,
                                style: TextStyle(fontSize: 13,
                                    color: _deadline.isEmpty ? text2 : textColor),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _field('Sales Task ID *', _salesTaskCtrl, textColor, text2, w: 200),
                  _field('Notes for Writer', _notesCtrl, textColor, text2, w: 580, lines: 3),
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
                TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Task',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _lbl(String t, Color c) => Text(t,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c));

  Widget _field(String lbl, TextEditingController ctrl, Color tc, Color t2,
      {double w = 180, int lines = 1, TextInputType? kb}) =>
      SizedBox(
        width: w,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(lbl, t2),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl, maxLines: lines, keyboardType: kb,
            style: TextStyle(fontSize: 13, color: tc),
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ]),
      );

  Widget _dropdown(String lbl, List<String> items, String val,
      ValueChanged<String?> onChange, Color tc, Color t2, Color s2) =>
      SizedBox(
        width: 180,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl(lbl, t2),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: items.contains(val) ? val : items.first,
            items: items.map((s) => DropdownMenuItem(value: s,
                child: Text(s, style: TextStyle(fontSize: 13, color: tc)))).toList(),
            onChanged: onChange,
            dropdownColor: s2,
            style: TextStyle(fontSize: 13, color: tc),
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════
// COMMENTS DIALOG  (unchanged from original)
// ════════════════════════════════════════════════════════════════
class _CommentsDialog extends StatefulWidget {
  final TaskModel task;
  final UserModel user;
  final FirestoreService svc;
  const _CommentsDialog({required this.task, required this.user, required this.svc});
  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

// ════════════════════════════════════════════════════════════════
// REPLACE the entire _CommentsDialogState class in:
//   lib/screens/tasks/tasks_screen.dart
// Everything else in that file stays exactly the same.
// ════════════════════════════════════════════════════════════════

class _CommentsDialogState extends State<_CommentsDialog> {
  final _ctrl = TextEditingController();
  late List<Map<String, dynamic>> _comments;
  bool   _posting   = false;
  String _inputError = '';   // ← NEW: inline validation message

  // ── Validation constants ──────────────────────────────────────
  static const int _maxWords = 50;

  // Counts words (splits on whitespace, ignores empty parts)
  static int _wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  // Only letters (a-z, A-Z) and whitespace allowed
  static final _allowedChars = RegExp(r'^[a-zA-Z\s]*$');

  // Validate and return an error string, or '' if valid
  static String _validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Comment cannot be empty.';
    if (!_allowedChars.hasMatch(trimmed)) {
      return 'Only letters (a–z, A–Z) are allowed — no numbers or symbols.';
    }
    final wc = _wordCount(trimmed);
    if (wc > _maxWords) {
      return 'Comment is $_maxWords words max (currently $wc words).';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.task.comments);
    // Revalidate live so the counter / error updates as the user types
    _ctrl.addListener(() => setState(() {
      _inputError = _ctrl.text.trim().isEmpty ? '' : _validate(_ctrl.text);
    }));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text  = _ctrl.text.trim();
    final error = _validate(text);
    if (error.isNotEmpty) {
      setState(() => _inputError = error);
      return;
    }
    setState(() { _posting = true; _inputError = ''; });
    final comment = {
      'author': widget.user.name,//comment garda you ma username dekinxa
      'role':   widget.user.role,
      'userId': widget.user.userId,
      'text':   text,
      'time':   DateTime.now().toIso8601String(),
    };
    await widget.svc.addComment(widget.task.taskId, comment);
    if (mounted) {
      setState(() {
        _comments.add(comment);
        _ctrl.clear();
        _posting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final surface2  = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final border    = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText      : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2     : AppColors.lightText2;

    final roleColors = <String, Color>{
      'superadmin': AppColors.purple,
      'sales':      AppColors.accent,
      'teamleader': AppColors.yellow,
      'writer':     AppColors.green,
    };

    // ── Live word count for the input field ───────────────────
    final currentWords = _wordCount(_ctrl.text);
    final wordsLeft    = _maxWords - currentWords;
    final hasError     = _inputError.isNotEmpty;
    // Counter colour: green → yellow → red as user approaches limit
    final counterColor = wordsLeft > 15
        ? AppColors.green
        : wordsLeft > 5
        ? AppColors.yellow
        : AppColors.red;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Title bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Comments — ${widget.task.subject}',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: textColor),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_comments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_comments.length}',
                      style: const TextStyle(fontSize: 11,
                          color: AppColors.accent, fontWeight: FontWeight.w800)),
                ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18)),
            ]),
          ),
          Divider(color: border, height: 1),

          // ── Comment list ──────────────────────────────────────
          SizedBox(
            height: 300,
            child: _comments.isEmpty
                ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 40, color: text2),
                      const SizedBox(height: 10),
                      Text('No comments yet.',
                          style: TextStyle(fontSize: 13, color: text2)),
                    ]))
                : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _comments.length,
              itemBuilder: (_, i) {
                final c    = _comments[i];
                final time = DateTime.tryParse(c['time'] ?? '');
                final ts   = time != null
                    ? '${time.day}/${time.month}/${time.year}'
                    '  ${time.hour.toString().padLeft(2, '0')}'
                    ':${time.minute.toString().padLeft(2, '0')}'
                    : '';
                final rc   = roleColors[c['role']] ?? text2;
                final isMe = c['userId'] == widget.user.userId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.accent.withOpacity(0.07)
                        : surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isMe
                            ? AppColors.accent.withOpacity(0.25)
                            : border),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rc.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(c['author'] ?? '',
                                style: TextStyle(fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: rc)),
                          ),
                          const SizedBox(width: 8),
                          Text(ts,
                              style:
                              TextStyle(fontSize: 10.5, color: text2)),
                          if (isMe) ...[
                            const Spacer(),
                            Text('You',
                                style: TextStyle(fontSize: 10,
                                    color: text2,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ]),
                        const SizedBox(height: 5),
                        Text(c['text'] ?? '',
                            style: TextStyle(fontSize: 13,
                                color: textColor, height: 1.4)),
                      ]),
                );
              },
            ),
          ),

          Divider(color: border, height: 1),

          // ── Input area ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Validation rules hint ─────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12,
                        color: text2.withOpacity(0.6)),
                    const SizedBox(width: 5),
                    Text(
                      'Letters only (a–z) · max $_maxWords words',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: text2.withOpacity(0.7)),
                    ),
                  ]),
                ),

                // ── Text field ────────────────────────────────
                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Write a comment… (max 50 words, letters only)',
                    hintStyle: TextStyle(color: text2),
                    contentPadding: const EdgeInsets.all(10),
                    // Red border when there's an error
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: hasError
                              ? AppColors.red.withOpacity(0.6)
                              : border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: hasError ? AppColors.red : AppColors.accent,
                          width: 1.5),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _post(),
                ),

                const SizedBox(height: 6),

                // ── Error message OR word counter ─────────────
                Row(
                  children: [
                    if (hasError) ...[
                      const Icon(Icons.error_outline_rounded,
                          size: 13, color: AppColors.red),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _inputError,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.red),
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Word counter (always visible)
                    Text(
                      '$currentWords / $_maxWords words',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: currentWords == 0 ? text2 : counterColor),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Post button ───────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _posting ? null : _post,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size(90, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _posting
                        ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Text('Post',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}