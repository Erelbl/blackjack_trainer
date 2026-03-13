import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../engine/strategy/basic_strategy.dart';
import '../../services/analytics_service.dart';
import '../store/models/table_theme_item.dart';

// ---------------------------------------------------------------------------
// Table type selector
// ---------------------------------------------------------------------------
enum _TableType { hard, soft, pairs }

// ---------------------------------------------------------------------------
// Strategy Tables Tab
// ---------------------------------------------------------------------------
class StrategyTablesTab extends StatefulWidget {
  const StrategyTablesTab({super.key});

  @override
  State<StrategyTablesTab> createState() => _StrategyTablesTabState();
}

class _StrategyTablesTabState extends State<StrategyTablesTab> {
  _TableType _selected = _TableType.hard;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logStrategyTableOpen();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TypeSelector(
          selected: _selected,
          onChanged: (t) => setState(() => _selected = t),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            // Only the grid here — tiles are static below the legend.
            child: _buildTable(),
          ),
        ),
        const _Legend(),
        // Static tool tiles — outside the scroll so switching Hard/Soft/Pairs
        // never causes vertical jumping.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: const [
              _HouseEdgeTile(),
              SizedBox(height: 10),
              _SimulatorTile(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return switch (_selected) {
      _TableType.hard  => _StrategyGrid(
          table: BasicStrategy.hardTable,
          rowLabels: BasicStrategy.hardRowLabels,
          rowOrder: [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
        ),
      _TableType.soft  => _StrategyGrid(
          table: BasicStrategy.softTable,
          rowLabels: BasicStrategy.softRowLabels,
          rowOrder: [2, 3, 4, 5, 6, 7, 8, 9],
        ),
      _TableType.pairs => _StrategyGrid(
          table: BasicStrategy.pairsTable,
          rowLabels: BasicStrategy.pairsRowLabels,
          rowOrder: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Segmented selector: Hard / Soft / Pairs
// ---------------------------------------------------------------------------
class _TypeSelector extends StatelessWidget {
  final _TableType selected;
  final ValueChanged<_TableType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TableThemeTokens>();
    const types = _TableType.values;
    const labels = ['Hard', 'Soft', 'Pairs'];

    return Container(
      color: tokens?.darkFelt ?? AppTheme.darkFelt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(types.length, (i) {
          final isActive = types[i] == selected;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
              child: GestureDetector(
                onTap: () => onChanged(types[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.casinoGold
                        : (tokens?.mid.withValues(alpha: 0.5) ?? Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.black : Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strategy grid widget
// ---------------------------------------------------------------------------
class _StrategyGrid extends StatelessWidget {
  final Map<int, List<StrategyAction>> table;
  final Map<int, String> rowLabels;
  final List<int> rowOrder;

  const _StrategyGrid({
    required this.table,
    required this.rowLabels,
    required this.rowOrder,
  });

  @override
  Widget build(BuildContext context) {
    const dealerLabels = BasicStrategy.dealerUpcardLabels;
    const rowLabelW = 56.0;
    const cellW = 32.0;
    const cellH = 30.0;
    const headerH = 26.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: empty corner + dealer upcard labels
          Row(
            children: [
              SizedBox(width: rowLabelW), // corner
              ...dealerLabels.map(
                (label) => SizedBox(
                  width: cellW,
                  height: headerH,
                  child: Center(
                    child: Text(
                      label,
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.casinoGold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Data rows
          ...rowOrder.map((key) {
            final actions = table[key];
            if (actions == null) return const SizedBox.shrink();
            return Row(
              children: [
                // Row label
                SizedBox(
                  width: rowLabelW,
                  height: cellH,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rowLabels[key] ?? '$key',
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                // Action cells
                ...actions.map(
                  (action) => _ActionCell(action: action, size: cellW, height: cellH),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single cell in the grid
// ---------------------------------------------------------------------------
class _ActionCell extends StatelessWidget {
  final StrategyAction action;
  final double size;
  final double height;

  const _ActionCell({
    required this.action,
    required this.size,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: height,
      child: Center(
        child: Container(
          width: size - 4,
          height: height - 4,
          decoration: BoxDecoration(
            color: _bgColor(action),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            action.label,
            style: AppTheme.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  static Color _bgColor(StrategyAction action) => switch (action) {
        StrategyAction.hit        => const Color(0xFF1565C0), // blue
        StrategyAction.stand      => const Color(0xFF795548), // brown
        StrategyAction.doubleDown => const Color(0xFF2E7D32), // green
        StrategyAction.split      => const Color(0xFF6A1B9A), // purple
      };
}

// ---------------------------------------------------------------------------
// House Edge tile (navigates to /house-edge)
// ---------------------------------------------------------------------------
class _HouseEdgeTile extends StatelessWidget {
  const _HouseEdgeTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/house-edge'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.casinoGold.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.percent, color: AppTheme.casinoGold, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'House Edge',
                    style: AppTheme.bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Estimate table advantage for current rules',
                    style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simulator tile (navigates to /simulator)
// ---------------------------------------------------------------------------
class _SimulatorTile extends StatelessWidget {
  const _SimulatorTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/simulator'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.casinoGold.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppTheme.casinoGold, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simulator',
                    style: AppTheme.bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Simulate EV for current rules',
                    style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend
// ---------------------------------------------------------------------------
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = [
      (StrategyAction.hit,        'H = Hit'),
      (StrategyAction.stand,      'S = Stand'),
      (StrategyAction.doubleDown, 'D = Double'),
      (StrategyAction.split,      'P = Split'),
    ];

    final tokens = Theme.of(context).extension<TableThemeTokens>();
    return Container(
      color: tokens?.darkFelt ?? AppTheme.darkFelt,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          final (action, label) = item;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _ActionCell._bgColor(action),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  action.label,
                  style: AppTheme.bodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTheme.bodyStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
