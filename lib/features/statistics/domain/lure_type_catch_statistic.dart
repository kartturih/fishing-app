/// One lure type (the same open, stable string code used by
/// `LureModel.lureType`, MFS-015) paired with how many catches it has
/// produced in total, across every lure of that type. See MFS-019 / TD-019.
final class LureTypeCatchStatistic {
  const LureTypeCatchStatistic({
    required this.lureType,
    required this.catchCount,
  }) : assert(lureType != '', 'lureType must not be empty'),
       assert(catchCount > 0, 'catchCount must be greater than zero');

  final String lureType;
  final int catchCount;
}
