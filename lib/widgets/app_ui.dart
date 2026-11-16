import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../core/events/data_revision.dart';
import '../data/formatting.dart';
import '../l10n/ui_text.dart';
import '../theme/app_theme.dart';

/// Which number a compact KPI card shows.
///
/// All values come from the existing read model [v_dashboard_kpis], so a new
/// screen never needs its own aggregation query.
enum KpiKind {
  cashBalance,
  todaySales,
  lowStock,
  overdueReceivables,
  rentDue,
  staffPresent,
}

/// One compact summary number shown in the green header strip.
class KpiItem {
  const KpiItem({required this.label, required this.value});

  final String label;
  final String value;
}

/// A single line of two or three compact green cards.
///
/// The strip is part of the header, so its fixed height (58 dp) keeps the
/// whole header well under the 22 % screen-height budget.
class KpiStrip extends StatelessWidget {
  const KpiStrip({required this.items, super.key});

  final List<KpiItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _KpiCard(item: items[index]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final KpiItem item;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: BrandColors.leafGreen,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: BrandColors.gold, width: 1),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BrandColors.cream,
            fontSize: 11,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            item.value,
            maxLines: 1,
            style: const TextStyle(
              color: BrandColors.lightGold,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A [KpiStrip] that loads [v_dashboard_kpis] itself and refreshes whenever a
/// save bumps [DataRevision].
class DashboardKpiStrip extends StatefulWidget {
  const DashboardKpiStrip({required this.kinds, super.key});

  final List<KpiKind> kinds;

  @override
  State<DashboardKpiStrip> createState() => _DashboardKpiStripState();
}

class _DashboardKpiStripState extends State<DashboardKpiStrip> {
  Map<String, dynamic>? _data;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    DataRevision.notifier.addListener(_reload);
  }

  @override
  void dispose() {
    DataRevision.notifier.removeListener(_reload);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _reload() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    try {
      final row = await session.client
          .from('v_dashboard_kpis')
          .select()
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _data = row == null ? const {} : Map<String, dynamic>.from(row);
      });
    } catch (_) {
      // A summary strip must never block the screen; show dashes instead of a
      // technical error.
      if (!mounted) return;
      setState(() => _data = const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return KpiStrip(
        items: [
          for (final kind in widget.kinds)
            KpiItem(label: _label(context, kind), value: '…'),
        ],
      );
    }
    return KpiStrip(
      items: [
        for (final kind in widget.kinds)
          KpiItem(
            label: _label(context, kind),
            value: _value(context, kind, data[_field(kind)]),
          ),
      ],
    );
  }

  String _field(KpiKind kind) => switch (kind) {
    KpiKind.cashBalance => 'cash_balance',
    KpiKind.todaySales => 'today_sales',
    KpiKind.lowStock => 'low_stock_items',
    KpiKind.overdueReceivables => 'overdue_receivables',
    KpiKind.rentDue => 'rent_due',
    KpiKind.staffPresent => 'staff_present_today',
  };

  String _label(BuildContext context, KpiKind kind) =>
      uiText(context, switch (kind) {
        KpiKind.cashBalance => 'Cash balance',
        KpiKind.todaySales => "Today's sales",
        KpiKind.lowStock => 'Low stock',
        KpiKind.overdueReceivables => 'Overdue',
        KpiKind.rentDue => 'Rent due',
        KpiKind.staffPresent => 'Staff present',
      });

  String _value(BuildContext context, KpiKind kind, Object? raw) {
    final value = asNum(raw);
    return switch (kind) {
      KpiKind.lowStock || KpiKind.staffPresent => value.toStringAsFixed(0),
      _ => formatMoney(value),
    };
  }
}

/// A compact tab bar painted on the structural green band.
///
/// Flutter's [TabBar] has no background of its own; wrapping it here keeps the
/// app chrome green and the content areas cream, without every screen
/// repeating the same colour decision.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    required this.tabs,
    this.isScrollable = false,
    this.tabAlignment,
    super.key,
  });

  final List<Widget> tabs;
  final bool isScrollable;
  final TabAlignment? tabAlignment;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: BrandColors.deepGreen,
    child: TabBar(
      isScrollable: isScrollable,
      tabAlignment: tabAlignment,
      tabs: tabs,
    ),
  );
}

/// The compact one-row toolbar: a full-width search field plus icon-only
/// actions. No labelled button row, no technical text.
class AppToolbar extends StatelessWidget {
  const AppToolbar({
    required this.searchController,
    required this.onSearchChanged,
    this.onRefresh,
    this.onCsv,
    this.onPdf,
    this.onAdd,
    super.key,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onCsv;
  final VoidCallback? onPdf;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: BrandColors.deepGreen,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  hintText: uiText(context, 'Search records'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: uiText(context, 'Clear search'),
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (onRefresh != null)
            _ToolbarIcon(
              tooltip: uiText(context, 'Refresh'),
              icon: Icons.refresh,
              onPressed: onRefresh,
            ),
          if (onCsv != null)
            _ToolbarIcon(
              tooltip: uiText(context, 'Export CSV'),
              icon: Icons.download_outlined,
              onPressed: onCsv,
            ),
          if (onPdf != null)
            _ToolbarIcon(
              tooltip: uiText(context, 'Export PDF'),
              icon: Icons.picture_as_pdf_outlined,
              onPressed: onPdf,
            ),
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: uiText(context, 'Add'),
                child: Material(
                  color: BrandColors.gold,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.add,
                        color: BrandColors.deepGreen,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    color: BrandColors.cream,
    icon: Icon(icon, size: 20),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: onPressed,
  );
}

/// A compact record card: ivory surface, green left accent, a title row, one
/// secondary line, an optional status chip and an overflow menu.
class AppListCard extends StatelessWidget {
  const AppListCard({
    required this.title,
    this.subtitle,
    this.trailingText,
    this.icon,
    this.statusLabel,
    this.statusColor,
    this.onTap,
    this.onDelete,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final IconData? icon;
  final String? statusLabel;
  final Color? statusColor;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = statusColor ?? BrandColors.forestGreen;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: BrandColors.forestGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: BrandColors.forestGreen),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.15,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.ink,
                              ),
                            ),
                          ),
                          if (trailingText != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                trailingText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: BrandColors.chocolate,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      statusLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                ],
                if (trailing != null)
                  trailing!
                else if (onDelete != null)
                  IconButton(
                    tooltip: uiText(context, 'Row actions'),
                    icon: const Icon(Icons.more_vert, size: 18),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
