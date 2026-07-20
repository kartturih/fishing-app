import 'package:flutter/material.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/features/catch_photos/data/catch_photo_repository.dart';
import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/presentation/widgets/catch_list_item.dart';

/// A "Hall of Fame" presentation for one Top 3 Largest Catches entry: the
/// existing, unmodified `CatchListItem` (catches, MFS-014) inside a
/// medal-bordered `Card`, with its rank number floating as a small badge
/// that overlaps the card's top border — the card "wearing" its rank,
/// rather than a separate badge sitting beside a plain list row. See
/// MFS-020 / TD-020 Key Design Decision 7; refined for visual prominence
/// after physical Android testing (an initial left-side badge, then this
/// floating, medal-bordered redesign). `CatchListItem` itself is never
/// modified or forked, and no navigation changes — this remains a
/// composition, not a new catch-row widget.
class RankedLargestCatchRow extends StatelessWidget {
  const RankedLargestCatchRow({
    super.key,
    required this.rank,
    required this.catchModel,
    required this.catchPhotoRepository,
    required this.onTap,
  }) : assert(rank >= 1 && rank <= 3, 'rank must be between 1 and 3');

  final int rank;
  final Catch catchModel;
  final CatchPhotoRepository catchPhotoRepository;
  final VoidCallback onTap;

  bool get _isFirstPlace => rank == 1;

  /// Caps how wide a single card grows, so the Top 3 list reads as
  /// centered content rather than edge-to-edge on wide screens — on
  /// typical phone widths this has no visible effect.
  static const double _maxCardWidth = 560;

  @override
  Widget build(BuildContext context) {
    final medal = _medalForRank(rank);
    final badgeRadius = _isFirstPlace ? 18.0 : 15.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxCardWidth),
        // `alignment: topCenter` places every non-positioned child's own
        // top edge at the stack's top and centers it horizontally. The
        // card is wrapped in `Padding(top: badgeRadius)`, so its visible
        // border starts exactly `badgeRadius` below the stack's top — the
        // same point where the badge (radius `badgeRadius`, so its own
        // vertical center sits at `badgeRadius`) is drawn. No negative
        // offsets or manually tuned overlap constants are needed, and the
        // badge's space is genuinely reserved in layout, so it can never
        // paint over a neighboring card or the section header above it.
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: EdgeInsets.only(top: badgeRadius),
              child: Card(
                elevation: _isFirstPlace ? 4 : 1,
                // A very subtle warm tint, blended from the medal gold onto
                // the theme's own surface color so it stays understated and
                // adapts to light/dark mode rather than using a fixed
                // literal background.
                color: _isFirstPlace
                    ? Color.alphaBlend(
                        medal.border.withValues(alpha: 0.06),
                        colorScheme.surface,
                      )
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  side: BorderSide(
                    color: medal.border,
                    width: _isFirstPlace ? 3 : 2,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    badgeRadius + AppSpacing.xs,
                    AppSpacing.md,
                    _isFirstPlace ? AppSpacing.md : AppSpacing.sm,
                  ),
                  child: CatchListItem(
                    catchModel: catchModel,
                    catchPhotoRepository: catchPhotoRepository,
                    onTap: onTap,
                  ),
                ),
              ),
            ),
            _RankBadge(rank: rank, medal: medal, radius: badgeRadius),
          ],
        ),
      ),
    );
  }
}

/// A rank's medal styling: fixed gold/silver/bronze colors, intentionally
/// independent of the app's teal-seeded [ColorScheme] — the same way a
/// medal's colors read the same regardless of an app's own theme. Reusing
/// Flutter's own [Colors.amber] for gold keeps the palette anchored to
/// Material's own color set rather than inventing an unrelated one.
class _Medal {
  const _Medal({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

const _goldMedal = _Medal(
  background: Colors.amber,
  foreground: Color(0xFF6B4A00),
  // Material Amber 700 — brighter and warmer than the previous dark
  // goldenrod tone, reading clearly as "gold" rather than "bronze".
  border: Color(0xFFFFA000),
);
const _silverMedal = _Medal(
  background: Color(0xFFD9DEE3),
  foreground: Color(0xFF3F4750),
  border: Color(0xFF8C97A3),
);
const _bronzeMedal = _Medal(
  background: Color(0xFFDBA876),
  foreground: Color(0xFF5A3416),
  border: Color(0xFF9C6636),
);

_Medal _medalForRank(int rank) {
  switch (rank) {
    case 1:
      return _goldMedal;
    case 2:
      return _silverMedal;
    default:
      return _bronzeMedal;
  }
}

/// The small circular badge floating above a card's top border, carrying
/// only the rank number — no icon, no emoji, matching MFS-020's existing
/// "a numbered badge is unambiguous regardless of locale or font support"
/// rationale (TD-020 Key Design Decision 7), now relocated onto the card
/// itself instead of sitting to its left.
class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.medal,
    required this.radius,
  });

  final int rank;
  final _Medal medal;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Semantics(
      label: '$rank. sija',
      container: true,
      excludeSemantics: true,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: medal.background,
          // A ring in the page's own surface color separates the badge
          // from the border color underneath it, so the two colors never
          // visually blend into each other where they overlap.
          border: Border.all(color: surface, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$rank',
          style: TextStyle(
            color: medal.foreground,
            fontWeight: FontWeight.bold,
            fontSize: radius,
          ),
        ),
      ),
    );
  }
}
