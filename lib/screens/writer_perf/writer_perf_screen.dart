// lib/screens/writer_perf/writer_perf_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/export_service.dart';
import '../../widgets/sticky_table.dart';

class WriterPerfScreen extends StatefulWidget {
  const WriterPerfScreen({super.key});
  @override
  State<WriterPerfScreen> createState() => _WriterPerfScreenState();
}

class _WriterPerfScreenState extends State<WriterPerfScreen> {
  final _svc    = FirestoreService();
  final _export = ExportService();
  List<Map<String, dynamic>> _stats = [];
  bool _loading = true;
  String _exporting = '';

  static const _cols = [
    TableCol('Writer', 180),
    TableCol('Total', 75),
    TableCol('Done', 75),
    TableCol('Pending', 80),
    TableCol('Late', 75),
    TableCol('On-Time Rate', 140),
    TableCol('Completion Rate', 155),
    TableCol('Export', 110),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = context.read<AuthProvider>().currentUser!;
    final stats = await _svc.getWriterStats(user);
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg     : AppColors.lightBg;
    final surface   = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border    = isDark ? AppColors.darkBorder  : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText    : AppColors.lightText;
    final text2     = isDark ? AppColors.darkText2   : AppColors.lightText2;
    final surface3  = isDark ? AppColors.darkSurface3: AppColors.lightSurface3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Writer Performance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                Text('On-time rate and completion tracking per writer',
                    style: TextStyle(fontSize: 12, color: text2)),
              ],
            )),
            // Refresh button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _load,
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.refresh_rounded, size: 14, color: AppColors.accent),
                    SizedBox(width: 5),
                    Text('Refresh',
                        style: TextStyle(fontSize: 12, color: AppColors.accent,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        // ── Table ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : StickyTable(
              columns: _cols,
              isDark: isDark,
              emptyMessage: 'No writer data yet',
              emptySubMessage:
              'Writer performance will appear after tasks are assigned and completed',
              emptyIcon: Icons.bar_chart_rounded,
              rows: _stats.map((s) {
                final onTimeRate     = s['onTimeRate']     as int? ?? 0;
                final completionRate = s['completionRate'] as int? ?? 0;
                final name           = s['name']?.toString() ?? '';
                final writerId       = s['writerId']?.toString() ?? '';

                // colour for on-time rate
                Color rateColor;
                if (onTimeRate >= 80) rateColor = AppColors.green;
                else if (onTimeRate >= 50) rateColor = AppColors.yellow;
                else rateColor = AppColors.red;

                // Avatar initials
                final initials = name
                    .split(' ')
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase();

                return [
                  // Writer name + avatar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.accent,
                            AppColors.accent2,
                          ]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(initials,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 11, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: textColor))),
                    ]),
                  ),

                  // Total
                  _numCell(s['total'].toString(), AppColors.accent, isDark),

                  // Done
                  _numCell(s['done'].toString(), AppColors.green, isDark),

                  // Pending
                  _numCell(s['pending'].toString(), AppColors.yellow, isDark),

                  // Late
                  _numCell(s['late'].toString(), AppColors.red, isDark),

                  // On-time rate with progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$onTimeRate%',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: rateColor,
                                    fontFamily: 'monospace')),
                            Text(onTimeRate >= 80
                                ? '🟢'
                                : onTimeRate >= 50
                                ? '🟡'
                                : '🔴',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: onTimeRate / 100,
                            minHeight: 5,
                            backgroundColor: surface3,
                            valueColor:
                            AlwaysStoppedAnimation(rateColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Completion rate with progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$completionRate%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: completionRate / 100,
                            minHeight: 5,
                            backgroundColor: surface3,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Export button (admin only)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: _exportBtn(name, writerId, isDark),
                  ),
                ];
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Small stat number box ────────────────────────────────────
  Widget _numCell(String val, Color color, bool isDark) {
    final surface2 =
    isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(val,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'monospace')),
        ),
      ),
    );
  }

  // ── Export tasks button for a writer ─────────────────────────
  Widget _exportBtn(String name, String writerId, bool isDark) {
    final isLoading = _exporting == writerId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : () => _doExport(name, writerId),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.purple.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isLoading)
              const SizedBox(
                width: 11, height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: AppColors.purple),
              )
            else
              const Icon(Icons.download_outlined,
                  size: 12, color: AppColors.purple),
            const SizedBox(width: 4),
            const Text('Tasks',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple)),
          ]),
        ),
      ),
    );
  }

  Future<void> _doExport(String name, String writerId) async {
    setState(() => _exporting = writerId);
    try {
      // Build a minimal UserModel for the export call
      final allUsers = await _svc.getAllUsers();
      final writer = allUsers.firstWhere(
            (u) => u.userId == writerId,
        orElse: () => allUsers.first,
      );
      await _export.exportWriterTasks(writer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $name tasks exported to Excel!'),
          backgroundColor: AppColors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    }
    if (mounted) setState(() => _exporting = '');
  }
}