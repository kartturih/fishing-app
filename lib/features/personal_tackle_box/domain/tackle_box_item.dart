import 'package:fishing_app/features/lure_catalog/domain/lure_catalog_entry.dart';
import 'package:fishing_app/features/personal_tackle_box/domain/tackle_box_entry.dart';

/// The joined read-model returned by every `PersonalTackleBoxRepository`
/// browse/get query: a [TackleBoxEntry] combined with its resolved catalog
/// data.
///
/// [catalogEntry] is `lure_catalog`'s own [LureCatalogEntry], reused
/// directly rather than duplicated — the concrete expression of MFS-016's
/// "reference, not copy" data rule. See MFS-016 / TD-016.
final class TackleBoxItem {
  const TackleBoxItem({required this.entry, required this.catalogEntry});

  final TackleBoxEntry entry;
  final LureCatalogEntry catalogEntry;

  String get id => entry.id;
  String? get personalPhotoRelativePath => entry.personalPhotoRelativePath;
}
