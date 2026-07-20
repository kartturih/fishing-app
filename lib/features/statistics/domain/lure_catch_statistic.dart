import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';

/// One catalog lure paired with how many catches it has produced. See
/// MFS-019 / TD-019.
final class LureCatchStatistic {
  const LureCatchStatistic({required this.lure, required this.catchCount})
    : assert(catchCount > 0, 'catchCount must be greater than zero');

  /// Reused directly from `lure_catalog` — never duplicated. See
  /// TD-019 §3.
  final LureCatalogEntry lure;
  final int catchCount;
}
