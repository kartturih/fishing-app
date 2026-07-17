// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FishingSpotsTable extends FishingSpots
    with TableInfo<$FishingSpotsTable, FishingSpotEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FishingSpotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fishing_spots';
  @override
  VerificationContext validateIntegrity(
    Insertable<FishingSpotEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FishingSpotEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FishingSpotEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FishingSpotsTable createAlias(String alias) {
    return $FishingSpotsTable(attachedDatabase, alias);
  }
}

class FishingSpotEntity extends DataClass
    implements Insertable<FishingSpotEntity> {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int createdAt;
  const FishingSpotEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  FishingSpotsCompanion toCompanion(bool nullToAbsent) {
    return FishingSpotsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      createdAt: Value(createdAt),
    );
  }

  factory FishingSpotEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FishingSpotEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  FishingSpotEntity copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    int? createdAt,
  }) => FishingSpotEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    createdAt: createdAt ?? this.createdAt,
  );
  FishingSpotEntity copyWithCompanion(FishingSpotsCompanion data) {
    return FishingSpotEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FishingSpotEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FishingSpotEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.createdAt == this.createdAt);
}

class FishingSpotsCompanion extends UpdateCompanion<FishingSpotEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> createdAt;
  final Value<int> rowid;
  const FishingSpotsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FishingSpotsCompanion.insert({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       createdAt = Value(createdAt);
  static Insertable<FishingSpotEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FishingSpotsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return FishingSpotsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FishingSpotsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatchesTable extends Catches with TableInfo<$CatchesTable, CatchEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fishingSpotIdMeta = const VerificationMeta(
    'fishingSpotId',
  );
  @override
  late final GeneratedColumn<String> fishingSpotId = GeneratedColumn<String>(
    'fishing_spot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES fishing_spots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _speciesMeta = const VerificationMeta(
    'species',
  );
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
    'species',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caughtAtMeta = const VerificationMeta(
    'caughtAt',
  );
  @override
  late final GeneratedColumn<int> caughtAt = GeneratedColumn<int>(
    'caught_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightGramsMeta = const VerificationMeta(
    'weightGrams',
  );
  @override
  late final GeneratedColumn<int> weightGrams = GeneratedColumn<int>(
    'weight_grams',
    aliasedName,
    true,
    check: () =>
        weightGrams.isNull() | ComparableExpr(weightGrams).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lengthMillimetersMeta = const VerificationMeta(
    'lengthMillimeters',
  );
  @override
  late final GeneratedColumn<int> lengthMillimeters = GeneratedColumn<int>(
    'length_millimeters',
    aliasedName,
    true,
    check: () =>
        lengthMillimeters.isNull() |
        ComparableExpr(lengthMillimeters).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fishingSpotId,
    species,
    caughtAt,
    weightGrams,
    lengthMillimeters,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catches';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatchEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('fishing_spot_id')) {
      context.handle(
        _fishingSpotIdMeta,
        fishingSpotId.isAcceptableOrUnknown(
          data['fishing_spot_id']!,
          _fishingSpotIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fishingSpotIdMeta);
    }
    if (data.containsKey('species')) {
      context.handle(
        _speciesMeta,
        species.isAcceptableOrUnknown(data['species']!, _speciesMeta),
      );
    } else if (isInserting) {
      context.missing(_speciesMeta);
    }
    if (data.containsKey('caught_at')) {
      context.handle(
        _caughtAtMeta,
        caughtAt.isAcceptableOrUnknown(data['caught_at']!, _caughtAtMeta),
      );
    } else if (isInserting) {
      context.missing(_caughtAtMeta);
    }
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('length_millimeters')) {
      context.handle(
        _lengthMillimetersMeta,
        lengthMillimeters.isAcceptableOrUnknown(
          data['length_millimeters']!,
          _lengthMillimetersMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatchEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatchEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fishingSpotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fishing_spot_id'],
      )!,
      species: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species'],
      )!,
      caughtAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}caught_at'],
      )!,
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_grams'],
      ),
      lengthMillimeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length_millimeters'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CatchesTable createAlias(String alias) {
    return $CatchesTable(attachedDatabase, alias);
  }
}

class CatchEntity extends DataClass implements Insertable<CatchEntity> {
  final String id;
  final String fishingSpotId;
  final String species;
  final int caughtAt;
  final int? weightGrams;
  final int? lengthMillimeters;
  final int createdAt;
  final int updatedAt;
  const CatchEntity({
    required this.id,
    required this.fishingSpotId,
    required this.species,
    required this.caughtAt,
    this.weightGrams,
    this.lengthMillimeters,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['fishing_spot_id'] = Variable<String>(fishingSpotId);
    map['species'] = Variable<String>(species);
    map['caught_at'] = Variable<int>(caughtAt);
    if (!nullToAbsent || weightGrams != null) {
      map['weight_grams'] = Variable<int>(weightGrams);
    }
    if (!nullToAbsent || lengthMillimeters != null) {
      map['length_millimeters'] = Variable<int>(lengthMillimeters);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CatchesCompanion toCompanion(bool nullToAbsent) {
    return CatchesCompanion(
      id: Value(id),
      fishingSpotId: Value(fishingSpotId),
      species: Value(species),
      caughtAt: Value(caughtAt),
      weightGrams: weightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(weightGrams),
      lengthMillimeters: lengthMillimeters == null && nullToAbsent
          ? const Value.absent()
          : Value(lengthMillimeters),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CatchEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatchEntity(
      id: serializer.fromJson<String>(json['id']),
      fishingSpotId: serializer.fromJson<String>(json['fishingSpotId']),
      species: serializer.fromJson<String>(json['species']),
      caughtAt: serializer.fromJson<int>(json['caughtAt']),
      weightGrams: serializer.fromJson<int?>(json['weightGrams']),
      lengthMillimeters: serializer.fromJson<int?>(json['lengthMillimeters']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fishingSpotId': serializer.toJson<String>(fishingSpotId),
      'species': serializer.toJson<String>(species),
      'caughtAt': serializer.toJson<int>(caughtAt),
      'weightGrams': serializer.toJson<int?>(weightGrams),
      'lengthMillimeters': serializer.toJson<int?>(lengthMillimeters),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CatchEntity copyWith({
    String? id,
    String? fishingSpotId,
    String? species,
    int? caughtAt,
    Value<int?> weightGrams = const Value.absent(),
    Value<int?> lengthMillimeters = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => CatchEntity(
    id: id ?? this.id,
    fishingSpotId: fishingSpotId ?? this.fishingSpotId,
    species: species ?? this.species,
    caughtAt: caughtAt ?? this.caughtAt,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    lengthMillimeters: lengthMillimeters.present
        ? lengthMillimeters.value
        : this.lengthMillimeters,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CatchEntity copyWithCompanion(CatchesCompanion data) {
    return CatchEntity(
      id: data.id.present ? data.id.value : this.id,
      fishingSpotId: data.fishingSpotId.present
          ? data.fishingSpotId.value
          : this.fishingSpotId,
      species: data.species.present ? data.species.value : this.species,
      caughtAt: data.caughtAt.present ? data.caughtAt.value : this.caughtAt,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      lengthMillimeters: data.lengthMillimeters.present
          ? data.lengthMillimeters.value
          : this.lengthMillimeters,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatchEntity(')
          ..write('id: $id, ')
          ..write('fishingSpotId: $fishingSpotId, ')
          ..write('species: $species, ')
          ..write('caughtAt: $caughtAt, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('lengthMillimeters: $lengthMillimeters, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fishingSpotId,
    species,
    caughtAt,
    weightGrams,
    lengthMillimeters,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatchEntity &&
          other.id == this.id &&
          other.fishingSpotId == this.fishingSpotId &&
          other.species == this.species &&
          other.caughtAt == this.caughtAt &&
          other.weightGrams == this.weightGrams &&
          other.lengthMillimeters == this.lengthMillimeters &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CatchesCompanion extends UpdateCompanion<CatchEntity> {
  final Value<String> id;
  final Value<String> fishingSpotId;
  final Value<String> species;
  final Value<int> caughtAt;
  final Value<int?> weightGrams;
  final Value<int?> lengthMillimeters;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CatchesCompanion({
    this.id = const Value.absent(),
    this.fishingSpotId = const Value.absent(),
    this.species = const Value.absent(),
    this.caughtAt = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.lengthMillimeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatchesCompanion.insert({
    required String id,
    required String fishingSpotId,
    required String species,
    required int caughtAt,
    this.weightGrams = const Value.absent(),
    this.lengthMillimeters = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fishingSpotId = Value(fishingSpotId),
       species = Value(species),
       caughtAt = Value(caughtAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CatchEntity> custom({
    Expression<String>? id,
    Expression<String>? fishingSpotId,
    Expression<String>? species,
    Expression<int>? caughtAt,
    Expression<int>? weightGrams,
    Expression<int>? lengthMillimeters,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fishingSpotId != null) 'fishing_spot_id': fishingSpotId,
      if (species != null) 'species': species,
      if (caughtAt != null) 'caught_at': caughtAt,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (lengthMillimeters != null) 'length_millimeters': lengthMillimeters,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? fishingSpotId,
    Value<String>? species,
    Value<int>? caughtAt,
    Value<int?>? weightGrams,
    Value<int?>? lengthMillimeters,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CatchesCompanion(
      id: id ?? this.id,
      fishingSpotId: fishingSpotId ?? this.fishingSpotId,
      species: species ?? this.species,
      caughtAt: caughtAt ?? this.caughtAt,
      weightGrams: weightGrams ?? this.weightGrams,
      lengthMillimeters: lengthMillimeters ?? this.lengthMillimeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fishingSpotId.present) {
      map['fishing_spot_id'] = Variable<String>(fishingSpotId.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (caughtAt.present) {
      map['caught_at'] = Variable<int>(caughtAt.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<int>(weightGrams.value);
    }
    if (lengthMillimeters.present) {
      map['length_millimeters'] = Variable<int>(lengthMillimeters.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatchesCompanion(')
          ..write('id: $id, ')
          ..write('fishingSpotId: $fishingSpotId, ')
          ..write('species: $species, ')
          ..write('caughtAt: $caughtAt, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('lengthMillimeters: $lengthMillimeters, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatchPhotosTable extends CatchPhotos
    with TableInfo<$CatchPhotosTable, CatchPhotoEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatchPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _catchIdMeta = const VerificationMeta(
    'catchId',
  );
  @override
  late final GeneratedColumn<String> catchId = GeneratedColumn<String>(
    'catch_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES catches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    catchId,
    relativePath,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catch_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatchPhotoEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('catch_id')) {
      context.handle(
        _catchIdMeta,
        catchId.isAcceptableOrUnknown(data['catch_id']!, _catchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_catchIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatchPhotoEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatchPhotoEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      catchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catch_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CatchPhotosTable createAlias(String alias) {
    return $CatchPhotosTable(attachedDatabase, alias);
  }
}

class CatchPhotoEntity extends DataClass
    implements Insertable<CatchPhotoEntity> {
  final String id;
  final String catchId;
  final String relativePath;
  final int sortOrder;
  final int createdAt;
  const CatchPhotoEntity({
    required this.id,
    required this.catchId,
    required this.relativePath,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['catch_id'] = Variable<String>(catchId);
    map['relative_path'] = Variable<String>(relativePath);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  CatchPhotosCompanion toCompanion(bool nullToAbsent) {
    return CatchPhotosCompanion(
      id: Value(id),
      catchId: Value(catchId),
      relativePath: Value(relativePath),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory CatchPhotoEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatchPhotoEntity(
      id: serializer.fromJson<String>(json['id']),
      catchId: serializer.fromJson<String>(json['catchId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'catchId': serializer.toJson<String>(catchId),
      'relativePath': serializer.toJson<String>(relativePath),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  CatchPhotoEntity copyWith({
    String? id,
    String? catchId,
    String? relativePath,
    int? sortOrder,
    int? createdAt,
  }) => CatchPhotoEntity(
    id: id ?? this.id,
    catchId: catchId ?? this.catchId,
    relativePath: relativePath ?? this.relativePath,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  CatchPhotoEntity copyWithCompanion(CatchPhotosCompanion data) {
    return CatchPhotoEntity(
      id: data.id.present ? data.id.value : this.id,
      catchId: data.catchId.present ? data.catchId.value : this.catchId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatchPhotoEntity(')
          ..write('id: $id, ')
          ..write('catchId: $catchId, ')
          ..write('relativePath: $relativePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, catchId, relativePath, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatchPhotoEntity &&
          other.id == this.id &&
          other.catchId == this.catchId &&
          other.relativePath == this.relativePath &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class CatchPhotosCompanion extends UpdateCompanion<CatchPhotoEntity> {
  final Value<String> id;
  final Value<String> catchId;
  final Value<String> relativePath;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> rowid;
  const CatchPhotosCompanion({
    this.id = const Value.absent(),
    this.catchId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatchPhotosCompanion.insert({
    required String id,
    required String catchId,
    required String relativePath,
    required int sortOrder,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       catchId = Value(catchId),
       relativePath = Value(relativePath),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt);
  static Insertable<CatchPhotoEntity> custom({
    Expression<String>? id,
    Expression<String>? catchId,
    Expression<String>? relativePath,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (catchId != null) 'catch_id': catchId,
      if (relativePath != null) 'relative_path': relativePath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatchPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? catchId,
    Value<String>? relativePath,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return CatchPhotosCompanion(
      id: id ?? this.id,
      catchId: catchId ?? this.catchId,
      relativePath: relativePath ?? this.relativePath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (catchId.present) {
      map['catch_id'] = Variable<String>(catchId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatchPhotosCompanion(')
          ..write('id: $id, ')
          ..write('catchId: $catchId, ')
          ..write('relativePath: $relativePath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FishingSpotsTable fishingSpots = $FishingSpotsTable(this);
  late final $CatchesTable catches = $CatchesTable(this);
  late final $CatchPhotosTable catchPhotos = $CatchPhotosTable(this);
  late final Index catchPhotosCatchIdSort = Index(
    'catch_photos_catch_id_sort',
    'CREATE INDEX catch_photos_catch_id_sort ON catch_photos (catch_id, sort_order)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    fishingSpots,
    catches,
    catchPhotos,
    catchPhotosCatchIdSort,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'fishing_spots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('catches', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'catches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('catch_photos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FishingSpotsTableCreateCompanionBuilder =
    FishingSpotsCompanion Function({
      required String id,
      required String name,
      required double latitude,
      required double longitude,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$FishingSpotsTableUpdateCompanionBuilder =
    FishingSpotsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$FishingSpotsTableReferences
    extends
        BaseReferences<_$AppDatabase, $FishingSpotsTable, FishingSpotEntity> {
  $$FishingSpotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CatchesTable, List<CatchEntity>>
  _catchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.catches,
    aliasName: 'fishing_spots__id__catches__fishing_spot_id',
  );

  $$CatchesTableProcessedTableManager get catchesRefs {
    final manager = $$CatchesTableTableManager(
      $_db,
      $_db.catches,
    ).filter((f) => f.fishingSpotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_catchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FishingSpotsTableFilterComposer
    extends Composer<_$AppDatabase, $FishingSpotsTable> {
  $$FishingSpotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> catchesRefs(
    Expression<bool> Function($$CatchesTableFilterComposer f) f,
  ) {
    final $$CatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.fishingSpotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchesTableFilterComposer(
            $db: $db,
            $table: $db.catches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FishingSpotsTableOrderingComposer
    extends Composer<_$AppDatabase, $FishingSpotsTable> {
  $$FishingSpotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FishingSpotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FishingSpotsTable> {
  $$FishingSpotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> catchesRefs<T extends Object>(
    Expression<T> Function($$CatchesTableAnnotationComposer a) f,
  ) {
    final $$CatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.fishingSpotId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.catches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FishingSpotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FishingSpotsTable,
          FishingSpotEntity,
          $$FishingSpotsTableFilterComposer,
          $$FishingSpotsTableOrderingComposer,
          $$FishingSpotsTableAnnotationComposer,
          $$FishingSpotsTableCreateCompanionBuilder,
          $$FishingSpotsTableUpdateCompanionBuilder,
          (FishingSpotEntity, $$FishingSpotsTableReferences),
          FishingSpotEntity,
          PrefetchHooks Function({bool catchesRefs})
        > {
  $$FishingSpotsTableTableManager(_$AppDatabase db, $FishingSpotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FishingSpotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FishingSpotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FishingSpotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FishingSpotsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double latitude,
                required double longitude,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FishingSpotsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FishingSpotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catchesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (catchesRefs) db.catches],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (catchesRefs)
                    await $_getPrefetchedData<
                      FishingSpotEntity,
                      $FishingSpotsTable,
                      CatchEntity
                    >(
                      currentTable: table,
                      referencedTable: $$FishingSpotsTableReferences
                          ._catchesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FishingSpotsTableReferences(
                            db,
                            table,
                            p0,
                          ).catchesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.fishingSpotId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FishingSpotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FishingSpotsTable,
      FishingSpotEntity,
      $$FishingSpotsTableFilterComposer,
      $$FishingSpotsTableOrderingComposer,
      $$FishingSpotsTableAnnotationComposer,
      $$FishingSpotsTableCreateCompanionBuilder,
      $$FishingSpotsTableUpdateCompanionBuilder,
      (FishingSpotEntity, $$FishingSpotsTableReferences),
      FishingSpotEntity,
      PrefetchHooks Function({bool catchesRefs})
    >;
typedef $$CatchesTableCreateCompanionBuilder =
    CatchesCompanion Function({
      required String id,
      required String fishingSpotId,
      required String species,
      required int caughtAt,
      Value<int?> weightGrams,
      Value<int?> lengthMillimeters,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CatchesTableUpdateCompanionBuilder =
    CatchesCompanion Function({
      Value<String> id,
      Value<String> fishingSpotId,
      Value<String> species,
      Value<int> caughtAt,
      Value<int?> weightGrams,
      Value<int?> lengthMillimeters,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$CatchesTableReferences
    extends BaseReferences<_$AppDatabase, $CatchesTable, CatchEntity> {
  $$CatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FishingSpotsTable _fishingSpotIdTable(_$AppDatabase db) => db
      .fishingSpots
      .createAlias('catches__fishing_spot_id__fishing_spots__id');

  $$FishingSpotsTableProcessedTableManager get fishingSpotId {
    final $_column = $_itemColumn<String>('fishing_spot_id')!;

    final manager = $$FishingSpotsTableTableManager(
      $_db,
      $_db.fishingSpots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fishingSpotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CatchPhotosTable, List<CatchPhotoEntity>>
  _catchPhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.catchPhotos,
    aliasName: 'catches__id__catch_photos__catch_id',
  );

  $$CatchPhotosTableProcessedTableManager get catchPhotosRefs {
    final manager = $$CatchPhotosTableTableManager(
      $_db,
      $_db.catchPhotos,
    ).filter((f) => f.catchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_catchPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CatchesTableFilterComposer
    extends Composer<_$AppDatabase, $CatchesTable> {
  $$CatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get caughtAt => $composableBuilder(
    column: $table.caughtAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FishingSpotsTableFilterComposer get fishingSpotId {
    final $$FishingSpotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fishingSpotId,
      referencedTable: $db.fishingSpots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FishingSpotsTableFilterComposer(
            $db: $db,
            $table: $db.fishingSpots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> catchPhotosRefs(
    Expression<bool> Function($$CatchPhotosTableFilterComposer f) f,
  ) {
    final $$CatchPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catchPhotos,
      getReferencedColumn: (t) => t.catchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchPhotosTableFilterComposer(
            $db: $db,
            $table: $db.catchPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatchesTable> {
  $$CatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get caughtAt => $composableBuilder(
    column: $table.caughtAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FishingSpotsTableOrderingComposer get fishingSpotId {
    final $$FishingSpotsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fishingSpotId,
      referencedTable: $db.fishingSpots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FishingSpotsTableOrderingComposer(
            $db: $db,
            $table: $db.fishingSpots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatchesTable> {
  $$CatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<int> get caughtAt =>
      $composableBuilder(column: $table.caughtAt, builder: (column) => column);

  GeneratedColumn<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FishingSpotsTableAnnotationComposer get fishingSpotId {
    final $$FishingSpotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fishingSpotId,
      referencedTable: $db.fishingSpots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FishingSpotsTableAnnotationComposer(
            $db: $db,
            $table: $db.fishingSpots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> catchPhotosRefs<T extends Object>(
    Expression<T> Function($$CatchPhotosTableAnnotationComposer a) f,
  ) {
    final $$CatchPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catchPhotos,
      getReferencedColumn: (t) => t.catchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.catchPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatchesTable,
          CatchEntity,
          $$CatchesTableFilterComposer,
          $$CatchesTableOrderingComposer,
          $$CatchesTableAnnotationComposer,
          $$CatchesTableCreateCompanionBuilder,
          $$CatchesTableUpdateCompanionBuilder,
          (CatchEntity, $$CatchesTableReferences),
          CatchEntity,
          PrefetchHooks Function({bool fishingSpotId, bool catchPhotosRefs})
        > {
  $$CatchesTableTableManager(_$AppDatabase db, $CatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fishingSpotId = const Value.absent(),
                Value<String> species = const Value.absent(),
                Value<int> caughtAt = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> lengthMillimeters = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatchesCompanion(
                id: id,
                fishingSpotId: fishingSpotId,
                species: species,
                caughtAt: caughtAt,
                weightGrams: weightGrams,
                lengthMillimeters: lengthMillimeters,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fishingSpotId,
                required String species,
                required int caughtAt,
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> lengthMillimeters = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatchesCompanion.insert(
                id: id,
                fishingSpotId: fishingSpotId,
                species: species,
                caughtAt: caughtAt,
                weightGrams: weightGrams,
                lengthMillimeters: lengthMillimeters,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({fishingSpotId = false, catchPhotosRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (catchPhotosRefs) db.catchPhotos,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (fishingSpotId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.fishingSpotId,
                                    referencedTable: $$CatchesTableReferences
                                        ._fishingSpotIdTable(db),
                                    referencedColumn: $$CatchesTableReferences
                                        ._fishingSpotIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (catchPhotosRefs)
                        await $_getPrefetchedData<
                          CatchEntity,
                          $CatchesTable,
                          CatchPhotoEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CatchesTableReferences
                              ._catchPhotosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).catchPhotosRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.catchId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatchesTable,
      CatchEntity,
      $$CatchesTableFilterComposer,
      $$CatchesTableOrderingComposer,
      $$CatchesTableAnnotationComposer,
      $$CatchesTableCreateCompanionBuilder,
      $$CatchesTableUpdateCompanionBuilder,
      (CatchEntity, $$CatchesTableReferences),
      CatchEntity,
      PrefetchHooks Function({bool fishingSpotId, bool catchPhotosRefs})
    >;
typedef $$CatchPhotosTableCreateCompanionBuilder =
    CatchPhotosCompanion Function({
      required String id,
      required String catchId,
      required String relativePath,
      required int sortOrder,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$CatchPhotosTableUpdateCompanionBuilder =
    CatchPhotosCompanion Function({
      Value<String> id,
      Value<String> catchId,
      Value<String> relativePath,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$CatchPhotosTableReferences
    extends BaseReferences<_$AppDatabase, $CatchPhotosTable, CatchPhotoEntity> {
  $$CatchPhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CatchesTable _catchIdTable(_$AppDatabase db) =>
      db.catches.createAlias('catch_photos__catch_id__catches__id');

  $$CatchesTableProcessedTableManager get catchId {
    final $_column = $_itemColumn<String>('catch_id')!;

    final manager = $$CatchesTableTableManager(
      $_db,
      $_db.catches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_catchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CatchPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $CatchPhotosTable> {
  $$CatchPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CatchesTableFilterComposer get catchId {
    final $$CatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catchId,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchesTableFilterComposer(
            $db: $db,
            $table: $db.catches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatchPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $CatchPhotosTable> {
  $$CatchPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CatchesTableOrderingComposer get catchId {
    final $$CatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catchId,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchesTableOrderingComposer(
            $db: $db,
            $table: $db.catches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatchPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatchPhotosTable> {
  $$CatchPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CatchesTableAnnotationComposer get catchId {
    final $$CatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.catchId,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.catches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CatchPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatchPhotosTable,
          CatchPhotoEntity,
          $$CatchPhotosTableFilterComposer,
          $$CatchPhotosTableOrderingComposer,
          $$CatchPhotosTableAnnotationComposer,
          $$CatchPhotosTableCreateCompanionBuilder,
          $$CatchPhotosTableUpdateCompanionBuilder,
          (CatchPhotoEntity, $$CatchPhotosTableReferences),
          CatchPhotoEntity,
          PrefetchHooks Function({bool catchId})
        > {
  $$CatchPhotosTableTableManager(_$AppDatabase db, $CatchPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatchPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatchPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatchPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> catchId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatchPhotosCompanion(
                id: id,
                catchId: catchId,
                relativePath: relativePath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String catchId,
                required String relativePath,
                required int sortOrder,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CatchPhotosCompanion.insert(
                id: id,
                catchId: catchId,
                relativePath: relativePath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CatchPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({catchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (catchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.catchId,
                                referencedTable: $$CatchPhotosTableReferences
                                    ._catchIdTable(db),
                                referencedColumn: $$CatchPhotosTableReferences
                                    ._catchIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CatchPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatchPhotosTable,
      CatchPhotoEntity,
      $$CatchPhotosTableFilterComposer,
      $$CatchPhotosTableOrderingComposer,
      $$CatchPhotosTableAnnotationComposer,
      $$CatchPhotosTableCreateCompanionBuilder,
      $$CatchPhotosTableUpdateCompanionBuilder,
      (CatchPhotoEntity, $$CatchPhotosTableReferences),
      CatchPhotoEntity,
      PrefetchHooks Function({bool catchId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FishingSpotsTableTableManager get fishingSpots =>
      $$FishingSpotsTableTableManager(_db, _db.fishingSpots);
  $$CatchesTableTableManager get catches =>
      $$CatchesTableTableManager(_db, _db.catches);
  $$CatchPhotosTableTableManager get catchPhotos =>
      $$CatchPhotosTableTableManager(_db, _db.catchPhotos);
}
