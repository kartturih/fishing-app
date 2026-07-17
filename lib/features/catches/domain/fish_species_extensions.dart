import 'package:fishing_app/features/catches/domain/fish_species.dart';

extension FishSpeciesDisplayName on FishSpecies {
  String get finnishName {
    switch (this) {
      case FishSpecies.pike:
        return 'Hauki';
      case FishSpecies.perch:
        return 'Ahven';
      case FishSpecies.zander:
        return 'Kuha';
      case FishSpecies.brownTrout:
        return 'Taimen';
      case FishSpecies.rainbowTrout:
        return 'Kirjolohi';
      case FishSpecies.atlanticSalmon:
        return 'Lohi';
      case FishSpecies.grayling:
        return 'Harjus';
      case FishSpecies.whitefish:
        return 'Siika';
      case FishSpecies.burbot:
        return 'Made';
      case FishSpecies.roach:
        return 'Särki';
      case FishSpecies.bream:
        return 'Lahna';
      case FishSpecies.ide:
        return 'Säyne';
      case FishSpecies.rudd:
        return 'Sorva';
      case FishSpecies.bleak:
        return 'Salakka';
      case FishSpecies.tench:
        return 'Suutari';
      case FishSpecies.crucianCarp:
        return 'Ruutana';
      case FishSpecies.carp:
        return 'Karppi';
      case FishSpecies.eel:
        return 'Ankerias';
      case FishSpecies.asp:
        return 'Toutain';
    }
  }
}
