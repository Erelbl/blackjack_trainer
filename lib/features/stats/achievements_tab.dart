import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../engine/progression/achievement_definitions.dart';
import '../../engine/progression/progression_manager.dart';

// Category sort order: mastery → challenges → trainer → game.
const _kCategoryOrder = {
  AchievementCategory.mastery:    0,
  AchievementCategory.challenges: 1,
  AchievementCategory.trainer:    2,
  AchievementCategory.game:       3,
};

/// Returns a deterministically sorted copy of [all]:
/// 1) category (mastery → challenges → trainer → game)
/// 2) threshold ascending
/// 3) id alphabetically (tie-break)
List<AchievementDefinition> _sorted(List<AchievementDefinition> all) {
  final copy = all.toList();
  copy.sort((a, b) {
    final ca = _kCategoryOrder[a.category] ?? 99;
    final cb = _kCategoryOrder[b.category] ?? 99;
    if (ca != cb) return ca.compareTo(cb);
    if (a.threshold != b.threshold) return a.threshold.compareTo(b.threshold);
    return a.id.compareTo(b.id);
  });
  return copy;
}

/// Grid of all achievements — locked ones shown in grey, unlocked in color.
/// Mounts inside a [TabBarView] in [StatsScreen].
class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  @override
  void initState() {
    super.initState();
    // Mark all pending "new" achievements as seen once the tab opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pm = ProgressionManager.instance;
      for (final id in pm.getNewAchievements()) {
        pm.markAchievementSeen(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressionManager.instance,
      builder: (_, __) {
        final pm = ProgressionManager.instance;
        if (!pm.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = _sorted(AchievementDefinitions.all);
        final unlockedCount =
            all.where((d) => pm.isAchievementUnlocked(d.id)).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 480 ? 4 : 3;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Completeness header ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      Text(
                        'Unlocked: ',
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        '$unlockedCount',
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.casinoGold,
                        ),
                      ),
                      Text(
                        ' / ${all.length}',
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Achievement grid ──────────────────────────────────────
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final def = all[i];
                      return _AchievementTile(
                        def: def,
                        unlocked: pm.isAchievementUnlocked(def.id),
                        isNew: pm.getNewAchievements().contains(def.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _AchievementTile extends StatefulWidget {
  final AchievementDefinition def;
  final bool unlocked;
  final bool isNew;

  const _AchievementTile({
    required this.def,
    required this.unlocked,
    required this.isNew,
  });

  @override
  State<_AchievementTile> createState() => _AchievementTileState();
}

class _AchievementTileState extends State<_AchievementTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.def.category);
    final condition = widget.def.description.isNotEmpty
        ? widget.def.description
        : 'Complete the required condition to unlock.';

    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Base card ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: widget.unlocked
                  ? color.withValues(alpha: 0.13)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.unlocked
                    ? color.withValues(alpha: 0.5)
                    : Colors.white12,
                width: widget.unlocked ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _categoryIcon(widget.def.category),
                  size: 26,
                  color: widget.unlocked ? color : Colors.white24,
                ),
                const SizedBox(height: 5),
                Text(
                  widget.def.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: widget.unlocked ? Colors.white : Colors.white30,
                  ),
                ),
                const SizedBox(height: 3),
                if (widget.unlocked)
                  Text(
                    condition,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyStyle(
                      fontSize: 7,
                      color: Colors.white38,
                    ),
                  )
                else
                  const Icon(Icons.lock, size: 13, color: Colors.white24),
              ],
            ),
          ),

          // ── Reveal overlay ────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _revealed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_revealed,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.def.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: widget.unlocked ? color : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (!widget.unlocked)
                      Text(
                        'How to unlock:',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyStyle(
                          fontSize: 7,
                          color: Colors.white38,
                        ),
                      ),
                    if (!widget.unlocked) const SizedBox(height: 2),
                    Text(
                      condition,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyStyle(
                        fontSize: 8,
                        color: widget.unlocked
                            ? Colors.white70
                            : Colors.white60,
                      ),
                    ),
                    if (widget.unlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        '✓ Unlocked',
                        style: AppTheme.bodyStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── NEW badge — Positioned so it never affects layout ─────────
          if (widget.isNew)
            Positioned(
              top: 4,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.chipRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NEW',
                    style: AppTheme.bodyStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _categoryColor(AchievementCategory cat) => switch (cat) {
        AchievementCategory.mastery    => AppTheme.casinoGold,
        AchievementCategory.game       => const Color(0xFF4FC3F7),
        AchievementCategory.trainer    => AppTheme.neonCyan,
        AchievementCategory.challenges => const Color(0xFFFF8A65),
      };

  IconData _categoryIcon(AchievementCategory cat) => switch (cat) {
        AchievementCategory.mastery    => Icons.military_tech,
        AchievementCategory.game       => Icons.casino,
        AchievementCategory.trainer    => Icons.school,
        AchievementCategory.challenges => Icons.task_alt,
      };
}
