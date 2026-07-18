import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_variant.dart';

void main() {
  LureVariant buildVariant({
    String id = 'variant-1',
    String lureModelId = 'model-1',
    String? variantName,
    String? colorName = 'Hot Craw',
    String? manufacturerColorCode,
    int? lengthMillimeters,
    int? weightGrams,
    int? minRunningDepthMillimeters,
    int? maxRunningDepthMillimeters,
    String? buoyancy,
  }) {
    return LureVariant(
      id: id,
      lureModelId: lureModelId,
      variantName: variantName,
      colorName: colorName,
      manufacturerColorCode: manufacturerColorCode,
      lengthMillimeters: lengthMillimeters,
      weightGrams: weightGrams,
      minRunningDepthMillimeters: minRunningDepthMillimeters,
      maxRunningDepthMillimeters: maxRunningDepthMillimeters,
      buoyancy: buoyancy,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully with only colorName present', () {
    final variant = buildVariant();
    expect(variant.colorName, 'Hot Craw');
  });

  test('constructs successfully with only variantName present', () {
    final variant = buildVariant(colorName: null, variantName: 'Glow');
    expect(variant.variantName, 'Glow');
  });

  test('constructs successfully with only manufacturerColorCode present', () {
    final variant = buildVariant(colorName: null, manufacturerColorCode: 'HCC');
    expect(variant.manufacturerColorCode, 'HCC');
  });

  test('rejects an empty id', () {
    expect(() => buildVariant(id: ''), throwsA(isA<AssertionError>()));
  });

  test('rejects an empty lureModelId', () {
    expect(() => buildVariant(lureModelId: ''), throwsA(isA<AssertionError>()));
  });

  test(
    'rejects a variant with variantName, colorName, and manufacturerColorCode all absent',
    () {
      expect(
        () => buildVariant(colorName: null),
        throwsA(isA<AssertionError>()),
      );
    },
  );

  test('rejects a non-positive lengthMillimeters', () {
    expect(
      () => buildVariant(lengthMillimeters: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a non-positive weightGrams', () {
    expect(() => buildVariant(weightGrams: -1), throwsA(isA<AssertionError>()));
  });

  test('rejects a non-positive minRunningDepthMillimeters', () {
    expect(
      () => buildVariant(minRunningDepthMillimeters: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('rejects a non-positive maxRunningDepthMillimeters', () {
    expect(
      () => buildVariant(maxRunningDepthMillimeters: 0),
      throwsA(isA<AssertionError>()),
    );
  });

  test(
    'rejects minRunningDepthMillimeters greater than maxRunningDepthMillimeters',
    () {
      expect(
        () => buildVariant(
          minRunningDepthMillimeters: 2000,
          maxRunningDepthMillimeters: 1000,
        ),
        throwsA(isA<AssertionError>()),
      );
    },
  );

  test('accepts equal min and max running depth', () {
    final variant = buildVariant(
      minRunningDepthMillimeters: 1000,
      maxRunningDepthMillimeters: 1000,
    );
    expect(variant.minRunningDepthMillimeters, 1000);
    expect(variant.maxRunningDepthMillimeters, 1000);
  });

  test('accepts a buoyancy code the application does not recognize', () {
    final variant = buildVariant(buoyancy: 'some_future_buoyancy');
    expect(variant.buoyancy, 'some_future_buoyancy');
  });
}
