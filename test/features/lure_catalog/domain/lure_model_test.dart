import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/features/lure_catalog/domain/lure_model.dart';

void main() {
  LureModel buildModel({
    String id = 'model-1',
    String manufacturer = 'Rapala',
    String modelName = 'X-Rap Shad XRS08',
    String lureType = 'crankbait',
  }) {
    return LureModel(
      id: id,
      manufacturer: manufacturer,
      modelName: modelName,
      lureType: lureType,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  test('constructs successfully with only required fields', () {
    final model = buildModel();

    expect(model.id, 'model-1');
    expect(model.manufacturer, 'Rapala');
    expect(model.modelName, 'X-Rap Shad XRS08');
    expect(model.lureType, 'crankbait');
    expect(model.productFamily, isNull);
    expect(model.defaultImageReference, isNull);
  });

  test('constructs successfully with all optional fields', () {
    final model = LureModel(
      id: 'model-1',
      manufacturer: 'Rapala',
      modelName: 'X-Rap Shad XRS08',
      lureType: 'crankbait',
      productFamily: 'X-Rap',
      defaultImageReference: 'assets/lure_catalog/x.png',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    expect(model.productFamily, 'X-Rap');
    expect(model.defaultImageReference, 'assets/lure_catalog/x.png');
  });

  test('rejects an empty id', () {
    expect(() => buildModel(id: ''), throwsA(isA<AssertionError>()));
  });

  test('rejects an empty manufacturer', () {
    expect(() => buildModel(manufacturer: ''), throwsA(isA<AssertionError>()));
  });

  test('rejects an empty modelName', () {
    expect(() => buildModel(modelName: ''), throwsA(isA<AssertionError>()));
  });

  test('rejects an empty lureType', () {
    expect(() => buildModel(lureType: ''), throwsA(isA<AssertionError>()));
  });

  test('accepts a lureType code the application does not recognize', () {
    final model = buildModel(lureType: 'some_future_type');
    expect(model.lureType, 'some_future_type');
  });
}
