// lib/widgets/sticky_table.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

// ── Enable mouse wheel + drag + trackpad on web/desktop ──────────
class _WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

// ── Column definition ────────────────────────────────────────────
class TableCol {
  final String label;
  final double width;
  final bool   center;
  const TableCol(this.label, this.width, {this.center = false});
}

// ── StickyTable ──────────────────────────────────────────────────
//
// Layout: sticky header row + vertically scrollable body.
// Both scroll horizontally together via ONE shared hScroll controller
// so the header always stays aligned with the data rows.
//
// pinnedCount is accepted for API compatibility but is not used to
// split the layout — it is only surfaced via the "Pinned cols N"
// badge in the toolbar. All columns stay in a single unified panel.
//
class StickyTable extends StatefulWidget {
  final List<TableCol>     columns;
  final List<List<Widget>> rows;
  final bool               isDark;
  final int                pinnedCount;     // kept for API compat / badge
  final String             emptyMessage;
  final String             emptySubMessage;
  final IconData           emptyIcon;

  const StickyTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.isDark,
    this.pinnedCount     = 0,
    this.emptyMessage    = 'No data found',
    this.emptySubMessage = '',
    this.emptyIcon       = Icons.inbox_outlined,
  });

  @override
  State<StickyTable> createState() => _StickyTableState();
}

class _StickyTableState extends State<StickyTable> {
  late final ScrollController _vScroll;
  late final ScrollController _hScroll;        // shared by header + body
  late final ScrollController _hScrollHeader;  // header mirror

  static const double _headerH = 40.0;

  @override
  void initState() {
    super.initState();
    _vScroll       = ScrollController();
    _hScroll       = ScrollController();
    _hScrollHeader = ScrollController();

    // Mirror body horizontal position into header
    _hScroll.addListener(() {
      if (_hScrollHeader.hasClients &&
          _hScrollHeader.offset != _hScroll.offset) {
        _hScrollHeader.jumpTo(_hScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _hScroll.dispose();
    _hScrollHeader.dispose();
    super.dispose();
  }

  double get _totalWidth =>
      widget.columns.fold(0.0, (s, c) => s + c.width);

  @override
  Widget build(BuildContext context) {
    final isDark   = widget.isDark;
    final border   = isDark ? AppColors.darkBorder   : AppColors.lightBorder;
    final headerBg = isDark ? AppColors.darkSurface2 : AppColors.lightSurface2;
    final text2    = isDark ? AppColors.darkText2    : AppColors.lightText2;

    if (widget.rows.isEmpty) {
      return _emptyState(text2, isDark);
    }

    return Column(
      children: [
        // ── Sticky header (horizontal scroll mirrors body) ─────────
        _buildHeader(headerBg, border, text2),

        // ── Scrollable body ────────────────────────────────────────
        Expanded(child: _buildBody(border, isDark)),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(Color headerBg, Color border, Color text2) {
    return Container(
      height: _headerH,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: ScrollConfiguration(
        behavior: _WebScrollBehavior(),
        child: SingleChildScrollView(
          controller: _hScrollHeader,
          scrollDirection: Axis.horizontal,
          // Header is driven by listener only — user scrolls the body
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: _totalWidth,
            child: Row(
              children: widget.columns.map((col) => SizedBox(
                width: col.width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Align(
                    alignment: col.center
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: Text(col.label,
                        style: TextStyle(
                            fontSize:    11,
                            fontWeight:  FontWeight.w700,
                            color:       text2,
                            letterSpacing: 0.5)),
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody(Color border, bool isDark) {
    return ScrollConfiguration(
      behavior: _WebScrollBehavior(),
      child: Scrollbar(
        controller: _vScroll,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _vScroll,
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          child: ScrollConfiguration(
            behavior: _WebScrollBehavior(),
            child: Scrollbar(
              controller: _hScroll,
              thumbVisibility: true,
              trackVisibility: true,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: _totalWidth,
                  child: Column(
                    children: widget.rows.asMap().entries.map((entry) {
                      final i     = entry.key;
                      final cells = entry.value;
                      final rowBg = _rowBg(i, isDark);

                      return Container(
                        decoration: BoxDecoration(
                          color: rowBg,
                          border: Border(
                              bottom: BorderSide(
                                  color: border.withOpacity(0.5))),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(
                              widget.columns.length,
                                  (ci) => SizedBox(
                                width: widget.columns[ci].width,
                                child: cells[ci],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _rowBg(int i, bool isDark) {
    if (i.isEven) return Colors.transparent;
    return isDark
        ? Colors.white.withOpacity(0.022)
        : Colors.black.withOpacity(0.022);
  }

  Widget _emptyState(Color text2, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.emptyIcon, size: 52, color: text2),
          const SizedBox(height: 12),
          Text(widget.emptyMessage,
              style: TextStyle(
                  fontSize:   15,
                  color:      text2,
                  fontWeight: FontWeight.w500)),
          if (widget.emptySubMessage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.emptySubMessage,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkText3
                        : AppColors.lightText3)),
          ],
        ],
      ),
    );
  }
}

// ── Cell builder helpers ─────────────────────────────────────────

Widget tCell(String text, {
  Color?    color,
  double    fontSize = 12.5,
  bool      mono     = false,
  bool      bold     = false,
  int       maxLines = 1,
  TextAlign align    = TextAlign.left,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Text(text,
        overflow:  TextOverflow.ellipsis,
        maxLines:  maxLines,
        textAlign: align,
        style: TextStyle(
          fontSize:   fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color:      color,
          fontFamily: mono ? 'monospace' : null,
          height:     1.3,
        )),
  );
}

Widget tAction(String label, Color color, VoidCallback onTap,
    {IconData? icon}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border:       Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: TextStyle(
                    fontSize:   11.5,
                    fontWeight: FontWeight.w700,
                    color:      color)),
          ],
        ),
      ),
    ),
  );
}

Widget tActions(List<Widget> buttons) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Wrap(spacing: 4, runSpacing: 4, children: buttons),
  );
}