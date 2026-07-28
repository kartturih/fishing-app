import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fishing_app/app/theme/app_radius.dart';
import 'package:fishing_app/app/theme/app_spacing.dart';
import 'package:fishing_app/core/map/maptiler_config.dart';

/// Compact, always-visible attribution control, shown for both base-map
/// selections whenever MapTiler is configured (MFS-027 FR-21; TD-027 §11) —
/// MapTiler's attribution requirement is identical for Outdoor
/// (Maastokartta's underlay) and Satellite Hybrid (Ilmakuva's complete base
/// map), so this widget's own visibility never branches on which `BaseMap`
/// is active.
///
/// **Revision 7 (TD-027 §24):** also carries SYKE's required CC BY 4.0
/// bathymetry attribution, as an additional line inside the same
/// tap-to-expand panel — extending, not triplicating, this already-designed
/// mechanism, since a third permanently-visible text block would be real,
/// avoidable clutter on a small mobile screen. Shown whenever
/// [sykeAttributionRequired] is true (the bathymetry overlay is actually
/// being served), for either base-map selection, since the overlay itself
/// is base-map-agnostic (MFS-027 Revision 7 Design Notes).
///
/// Displays MapTiler's own official logo (required on the Free plan this
/// project uses) — `assets/map/maptiler_logo.svg`, fetched once from
/// MapTiler's own public, unauthenticated resource endpoint
/// (`https://api.maptiler.com/resources/logo.svg`, confirmed directly
/// against MapTiler's official attribution guide, TD-027 §0) and bundled
/// locally, unmodified, exactly as it was downloaded — never redrawn,
/// approximated, or rebranded. Bundling it avoids an otherwise-unnecessary
/// live network request merely to render a static brand asset, mirroring
/// the existing `assets/map/` MML-preview-crop precedent (TD-026 §11).
///
/// Tapping the logo reveals the exact required attribution text
/// ("© MapTiler © OpenStreetMap contributors", both linked — verified
/// directly against MapTiler's official attribution guide, TD-027 §0),
/// plus SYKE's own CC BY 4.0 line when applicable, in a small, dismissible
/// sheet, satisfying MapTiler's documented mobile tap-to-expand allowance
/// for the textual attribution without permanently occupying screen space;
/// the logo itself remains continuously visible, per the Free-plan
/// requirement.
///
/// Positioned top-left, deliberately away from the existing bottom-left
/// `MapAttribution`, bottom-right `MapControls`, and upper-right
/// `BaseMapLayersControl`/selector — the one screen corner none of those
/// already occupy, so this addition can never overlap an existing control.
class MapTilerAttribution extends StatelessWidget {
  const MapTilerAttribution({
    super.key,
    this.configured,
    this.sykeAttributionRequired = false,
  });

  /// Whether MapTiler is configured. Defaults to the real
  /// `!MapTilerConfig.isMissing`; overridable only so a widget test can
  /// exercise the "configured" visual state without a real
  /// `--dart-define` value, which — being a compile-time constant — cannot
  /// be swapped per test case (the same constraint already documented for
  /// `MmlConfig` in `map_screen_test.dart`).
  final bool? configured;

  /// Whether SYKE's own CC BY 4.0 bathymetry attribution must additionally
  /// be shown inside the panel (TD-027 §24) — true whenever the bathymetry
  /// overlay is actually being served for the current style. Does not
  /// affect whether this widget itself renders at all: if MapTiler is
  /// unconfigured, the whole control still renders nothing (see [build]) —
  /// MapTiler's own attribution is not conditional on SYKE, but a
  /// standalone SYKE-only attribution surface is not designed by this
  /// milestone (TD-027 §24's own "extend, don't triplicate" reasoning).
  final bool sykeAttributionRequired;

  static const _logoAssetPath = 'assets/map/maptiler_logo.svg';
  static const _mapTilerCopyrightUrl = 'https://maptiler.com/copyright';
  static const _osmCopyrightUrl = 'https://openstreetmap.org/copyright';
  static const _mapTilerHomeUrl = 'https://www.maptiler.com';
  static const _sykeCopyrightUrl =
      'https://www.syke.fi/fi-fi/avoin_tieto/kayttoehdot';

  @override
  Widget build(BuildContext context) {
    final isConfigured = configured ?? !MapTilerConfig.isMissing;
    if (!isConfigured) {
      // No MapTiler content is being shown, so no attribution obligation
      // exists for it in this build.
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Material(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: InkWell(
              key: const Key('mapTilerAttributionButton'),
              borderRadius: BorderRadius.circular(AppRadius.small),
              onTap: () => _showAttributionSheet(context),
              child: Semantics(
                button: true,
                label: 'Karttatietojen lähteet',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: ExcludeSemantics(
                    child: SvgPicture.asset(_logoAssetPath, height: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAttributionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) =>
          _MapTilerAttributionSheet(sykeAttributionRequired: sykeAttributionRequired),
    );
  }
}

class _MapTilerAttributionSheet extends StatelessWidget {
  const _MapTilerAttributionSheet({required this.sykeAttributionRequired});

  final bool sykeAttributionRequired;

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Karttatietojen lähteet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _AttributionLink(
              key: const Key('mapTilerCopyrightLink'),
              label: '© MapTiler',
              onTap: () => _open(MapTilerAttribution._mapTilerCopyrightUrl),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AttributionLink(
              key: const Key('osmCopyrightLink'),
              label: '© OpenStreetMap contributors',
              onTap: () => _open(MapTilerAttribution._osmCopyrightUrl),
            ),
            const SizedBox(height: AppSpacing.md),
            _AttributionLink(
              key: const Key('mapTilerHomeLink'),
              label: 'MapTiler',
              onTap: () => _open(MapTilerAttribution._mapTilerHomeUrl),
            ),
            // SYKE bathymetry attribution (TD-027 §24) — CC BY 4.0 requires
            // naming the source and license whenever the data (or a
            // rendered work derived from it) is displayed. Shown only
            // while the bathymetry overlay is actually being served,
            // inside this same shared panel rather than a third
            // permanently-visible text block.
            if (sykeAttributionRequired) ...[
              const SizedBox(height: AppSpacing.md),
              _AttributionLink(
                key: const Key('sykeCopyrightLink'),
                label: '© SYKE — Syvyysaineisto (CC BY 4.0)',
                onTap: () => _open(MapTilerAttribution._sykeCopyrightUrl),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          decoration: TextDecoration.underline,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
