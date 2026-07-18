import 'package:fishing_app/features/catches/domain/catch.dart';
import 'package:fishing_app/features/catches/presentation/widgets/add_catch_bottom_sheet.dart';

/// Shared read-only display formatting for Catch fields, used by the Catch
/// list, Catch Details, and (for date/time) the Add/Edit Catch forms.
///
/// [formatCatchDate] and [formatCatchTime] remain in add_catch_bottom_sheet.dart
/// since they are also used to label the Add/Edit Catch date/time picker
/// buttons; the functions here build on top of them.
String formatCatchDateTime(DateTime dateTime) =>
    '${formatCatchDate(dateTime)} ${formatCatchTime(dateTime)}';

String formatCatchWeight(int grams) {
  if (grams < 1000) {
    return '$grams g';
  }
  return '${_formatTrimmedDecimal(grams / 1000, 3)} kg';
}

String formatCatchLength(int millimeters) {
  return '${_formatTrimmedDecimal(millimeters / 10, 1)} cm';
}

/// Joins weight and length into one display line (e.g. "3.2 kg • 78 cm"),
/// omitting either side that is missing and returning null if both are.
String? formatCatchMeasurementLine(Catch catchModel) {
  final parts = [
    if (catchModel.weightGrams != null)
      formatCatchWeight(catchModel.weightGrams!),
    if (catchModel.lengthMillimeters != null)
      formatCatchLength(catchModel.lengthMillimeters!),
  ];

  return parts.isEmpty ? null : parts.join(' • ');
}

String _formatTrimmedDecimal(double value, int maxDecimals) {
  var text = value.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
