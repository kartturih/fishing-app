import 'package:flutter_test/flutter_test.dart';

import 'package:fishing_app/core/map/base_map.dart';

void main() {
  test('fallback is Maastokartta', () {
    expect(BaseMap.fallback, BaseMap.maastokartta);
  });

  test('tileFileExtension differs between Maastokartta and Ilmakuva', () {
    expect(BaseMap.maastokartta.tileFileExtension, '.png');
    expect(BaseMap.ilmakuva.tileFileExtension, '.jpg');
  });

  test('mmlLayerId matches the verified MML WMTS layer identifiers', () {
    expect(BaseMap.maastokartta.mmlLayerId, 'maastokartta');
    expect(BaseMap.ilmakuva.mmlLayerId, 'ortokuva');
  });

  test('label is the Finnish display name', () {
    expect(BaseMap.maastokartta.label, 'Maastokartta');
    expect(BaseMap.ilmakuva.label, 'Ilmakuva');
  });

  test('attributionText names Maanmittauslaitos and the correct dataset', () {
    expect(
      BaseMap.maastokartta.attributionText,
      contains('Maanmittauslaitoksen'),
    );
    expect(BaseMap.maastokartta.attributionText, contains('Maastokartta'));
    expect(BaseMap.ilmakuva.attributionText, contains('Maanmittauslaitoksen'));
    expect(BaseMap.ilmakuva.attributionText, contains('Ortokuva'));
  });

  test('previewAssetPath points at a local bundled asset per base map', () {
    expect(
      BaseMap.maastokartta.previewAssetPath,
      'assets/map/maastokartta_preview.png',
    );
    expect(
      BaseMap.ilmakuva.previewAssetPath,
      'assets/map/ilmakuva_preview.jpg',
    );
  });
}
