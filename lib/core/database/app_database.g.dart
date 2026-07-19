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

class $LureModelsTable extends LureModels
    with TableInfo<$LureModelsTable, LureModelEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LureModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productFamilyMeta = const VerificationMeta(
    'productFamily',
  );
  @override
  late final GeneratedColumn<String> productFamily = GeneratedColumn<String>(
    'product_family',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelNameMeta = const VerificationMeta(
    'modelName',
  );
  @override
  late final GeneratedColumn<String> modelName = GeneratedColumn<String>(
    'model_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lureTypeMeta = const VerificationMeta(
    'lureType',
  );
  @override
  late final GeneratedColumn<String> lureType = GeneratedColumn<String>(
    'lure_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultImageReferenceMeta =
      const VerificationMeta('defaultImageReference');
  @override
  late final GeneratedColumn<String> defaultImageReference =
      GeneratedColumn<String>(
        'default_image_reference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedVersionMeta = const VerificationMeta(
    'seedVersion',
  );
  @override
  late final GeneratedColumn<int> seedVersion = GeneratedColumn<int>(
    'seed_version',
    aliasedName,
    true,
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
    manufacturer,
    productFamily,
    modelName,
    lureType,
    defaultImageReference,
    searchText,
    seedVersion,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lure_models';
  @override
  VerificationContext validateIntegrity(
    Insertable<LureModelEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manufacturerMeta);
    }
    if (data.containsKey('product_family')) {
      context.handle(
        _productFamilyMeta,
        productFamily.isAcceptableOrUnknown(
          data['product_family']!,
          _productFamilyMeta,
        ),
      );
    }
    if (data.containsKey('model_name')) {
      context.handle(
        _modelNameMeta,
        modelName.isAcceptableOrUnknown(data['model_name']!, _modelNameMeta),
      );
    } else if (isInserting) {
      context.missing(_modelNameMeta);
    }
    if (data.containsKey('lure_type')) {
      context.handle(
        _lureTypeMeta,
        lureType.isAcceptableOrUnknown(data['lure_type']!, _lureTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_lureTypeMeta);
    }
    if (data.containsKey('default_image_reference')) {
      context.handle(
        _defaultImageReferenceMeta,
        defaultImageReference.isAcceptableOrUnknown(
          data['default_image_reference']!,
          _defaultImageReferenceMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    if (data.containsKey('seed_version')) {
      context.handle(
        _seedVersionMeta,
        seedVersion.isAcceptableOrUnknown(
          data['seed_version']!,
          _seedVersionMeta,
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
  LureModelEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LureModelEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      )!,
      productFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_family'],
      ),
      modelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_name'],
      )!,
      lureType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lure_type'],
      )!,
      defaultImageReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_image_reference'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      seedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed_version'],
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
  $LureModelsTable createAlias(String alias) {
    return $LureModelsTable(attachedDatabase, alias);
  }
}

class LureModelEntity extends DataClass implements Insertable<LureModelEntity> {
  final String id;
  final String manufacturer;
  final String? productFamily;
  final String modelName;
  final String lureType;
  final String? defaultImageReference;
  final String searchText;
  final int? seedVersion;
  final int createdAt;
  final int updatedAt;
  const LureModelEntity({
    required this.id,
    required this.manufacturer,
    this.productFamily,
    required this.modelName,
    required this.lureType,
    this.defaultImageReference,
    required this.searchText,
    this.seedVersion,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['manufacturer'] = Variable<String>(manufacturer);
    if (!nullToAbsent || productFamily != null) {
      map['product_family'] = Variable<String>(productFamily);
    }
    map['model_name'] = Variable<String>(modelName);
    map['lure_type'] = Variable<String>(lureType);
    if (!nullToAbsent || defaultImageReference != null) {
      map['default_image_reference'] = Variable<String>(defaultImageReference);
    }
    map['search_text'] = Variable<String>(searchText);
    if (!nullToAbsent || seedVersion != null) {
      map['seed_version'] = Variable<int>(seedVersion);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LureModelsCompanion toCompanion(bool nullToAbsent) {
    return LureModelsCompanion(
      id: Value(id),
      manufacturer: Value(manufacturer),
      productFamily: productFamily == null && nullToAbsent
          ? const Value.absent()
          : Value(productFamily),
      modelName: Value(modelName),
      lureType: Value(lureType),
      defaultImageReference: defaultImageReference == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultImageReference),
      searchText: Value(searchText),
      seedVersion: seedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(seedVersion),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LureModelEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LureModelEntity(
      id: serializer.fromJson<String>(json['id']),
      manufacturer: serializer.fromJson<String>(json['manufacturer']),
      productFamily: serializer.fromJson<String?>(json['productFamily']),
      modelName: serializer.fromJson<String>(json['modelName']),
      lureType: serializer.fromJson<String>(json['lureType']),
      defaultImageReference: serializer.fromJson<String?>(
        json['defaultImageReference'],
      ),
      searchText: serializer.fromJson<String>(json['searchText']),
      seedVersion: serializer.fromJson<int?>(json['seedVersion']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'manufacturer': serializer.toJson<String>(manufacturer),
      'productFamily': serializer.toJson<String?>(productFamily),
      'modelName': serializer.toJson<String>(modelName),
      'lureType': serializer.toJson<String>(lureType),
      'defaultImageReference': serializer.toJson<String?>(
        defaultImageReference,
      ),
      'searchText': serializer.toJson<String>(searchText),
      'seedVersion': serializer.toJson<int?>(seedVersion),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LureModelEntity copyWith({
    String? id,
    String? manufacturer,
    Value<String?> productFamily = const Value.absent(),
    String? modelName,
    String? lureType,
    Value<String?> defaultImageReference = const Value.absent(),
    String? searchText,
    Value<int?> seedVersion = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => LureModelEntity(
    id: id ?? this.id,
    manufacturer: manufacturer ?? this.manufacturer,
    productFamily: productFamily.present
        ? productFamily.value
        : this.productFamily,
    modelName: modelName ?? this.modelName,
    lureType: lureType ?? this.lureType,
    defaultImageReference: defaultImageReference.present
        ? defaultImageReference.value
        : this.defaultImageReference,
    searchText: searchText ?? this.searchText,
    seedVersion: seedVersion.present ? seedVersion.value : this.seedVersion,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LureModelEntity copyWithCompanion(LureModelsCompanion data) {
    return LureModelEntity(
      id: data.id.present ? data.id.value : this.id,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      productFamily: data.productFamily.present
          ? data.productFamily.value
          : this.productFamily,
      modelName: data.modelName.present ? data.modelName.value : this.modelName,
      lureType: data.lureType.present ? data.lureType.value : this.lureType,
      defaultImageReference: data.defaultImageReference.present
          ? data.defaultImageReference.value
          : this.defaultImageReference,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      seedVersion: data.seedVersion.present
          ? data.seedVersion.value
          : this.seedVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LureModelEntity(')
          ..write('id: $id, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('productFamily: $productFamily, ')
          ..write('modelName: $modelName, ')
          ..write('lureType: $lureType, ')
          ..write('defaultImageReference: $defaultImageReference, ')
          ..write('searchText: $searchText, ')
          ..write('seedVersion: $seedVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    manufacturer,
    productFamily,
    modelName,
    lureType,
    defaultImageReference,
    searchText,
    seedVersion,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LureModelEntity &&
          other.id == this.id &&
          other.manufacturer == this.manufacturer &&
          other.productFamily == this.productFamily &&
          other.modelName == this.modelName &&
          other.lureType == this.lureType &&
          other.defaultImageReference == this.defaultImageReference &&
          other.searchText == this.searchText &&
          other.seedVersion == this.seedVersion &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LureModelsCompanion extends UpdateCompanion<LureModelEntity> {
  final Value<String> id;
  final Value<String> manufacturer;
  final Value<String?> productFamily;
  final Value<String> modelName;
  final Value<String> lureType;
  final Value<String?> defaultImageReference;
  final Value<String> searchText;
  final Value<int?> seedVersion;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LureModelsCompanion({
    this.id = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.productFamily = const Value.absent(),
    this.modelName = const Value.absent(),
    this.lureType = const Value.absent(),
    this.defaultImageReference = const Value.absent(),
    this.searchText = const Value.absent(),
    this.seedVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LureModelsCompanion.insert({
    required String id,
    required String manufacturer,
    this.productFamily = const Value.absent(),
    required String modelName,
    required String lureType,
    this.defaultImageReference = const Value.absent(),
    required String searchText,
    this.seedVersion = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       manufacturer = Value(manufacturer),
       modelName = Value(modelName),
       lureType = Value(lureType),
       searchText = Value(searchText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LureModelEntity> custom({
    Expression<String>? id,
    Expression<String>? manufacturer,
    Expression<String>? productFamily,
    Expression<String>? modelName,
    Expression<String>? lureType,
    Expression<String>? defaultImageReference,
    Expression<String>? searchText,
    Expression<int>? seedVersion,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (productFamily != null) 'product_family': productFamily,
      if (modelName != null) 'model_name': modelName,
      if (lureType != null) 'lure_type': lureType,
      if (defaultImageReference != null)
        'default_image_reference': defaultImageReference,
      if (searchText != null) 'search_text': searchText,
      if (seedVersion != null) 'seed_version': seedVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LureModelsCompanion copyWith({
    Value<String>? id,
    Value<String>? manufacturer,
    Value<String?>? productFamily,
    Value<String>? modelName,
    Value<String>? lureType,
    Value<String?>? defaultImageReference,
    Value<String>? searchText,
    Value<int?>? seedVersion,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LureModelsCompanion(
      id: id ?? this.id,
      manufacturer: manufacturer ?? this.manufacturer,
      productFamily: productFamily ?? this.productFamily,
      modelName: modelName ?? this.modelName,
      lureType: lureType ?? this.lureType,
      defaultImageReference:
          defaultImageReference ?? this.defaultImageReference,
      searchText: searchText ?? this.searchText,
      seedVersion: seedVersion ?? this.seedVersion,
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
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (productFamily.present) {
      map['product_family'] = Variable<String>(productFamily.value);
    }
    if (modelName.present) {
      map['model_name'] = Variable<String>(modelName.value);
    }
    if (lureType.present) {
      map['lure_type'] = Variable<String>(lureType.value);
    }
    if (defaultImageReference.present) {
      map['default_image_reference'] = Variable<String>(
        defaultImageReference.value,
      );
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (seedVersion.present) {
      map['seed_version'] = Variable<int>(seedVersion.value);
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
    return (StringBuffer('LureModelsCompanion(')
          ..write('id: $id, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('productFamily: $productFamily, ')
          ..write('modelName: $modelName, ')
          ..write('lureType: $lureType, ')
          ..write('defaultImageReference: $defaultImageReference, ')
          ..write('searchText: $searchText, ')
          ..write('seedVersion: $seedVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LureVariantsTable extends LureVariants
    with TableInfo<$LureVariantsTable, LureVariantEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LureVariantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lureModelIdMeta = const VerificationMeta(
    'lureModelId',
  );
  @override
  late final GeneratedColumn<String> lureModelId = GeneratedColumn<String>(
    'lure_model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lure_models (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _variantNameMeta = const VerificationMeta(
    'variantName',
  );
  @override
  late final GeneratedColumn<String> variantName = GeneratedColumn<String>(
    'variant_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorNameMeta = const VerificationMeta(
    'colorName',
  );
  @override
  late final GeneratedColumn<String> colorName = GeneratedColumn<String>(
    'color_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manufacturerColorCodeMeta =
      const VerificationMeta('manufacturerColorCode');
  @override
  late final GeneratedColumn<String> manufacturerColorCode =
      GeneratedColumn<String>(
        'manufacturer_color_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
  static const VerificationMeta _minRunningDepthMillimetersMeta =
      const VerificationMeta('minRunningDepthMillimeters');
  @override
  late final GeneratedColumn<int> minRunningDepthMillimeters =
      GeneratedColumn<int>(
        'min_running_depth_millimeters',
        aliasedName,
        true,
        check: () =>
            minRunningDepthMillimeters.isNull() |
            ComparableExpr(minRunningDepthMillimeters).isBiggerThanValue(0),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _maxRunningDepthMillimetersMeta =
      const VerificationMeta('maxRunningDepthMillimeters');
  @override
  late final GeneratedColumn<int> maxRunningDepthMillimeters =
      GeneratedColumn<int>(
        'max_running_depth_millimeters',
        aliasedName,
        true,
        check: () =>
            maxRunningDepthMillimeters.isNull() |
            ComparableExpr(maxRunningDepthMillimeters).isBiggerThanValue(0),
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _buoyancyMeta = const VerificationMeta(
    'buoyancy',
  );
  @override
  late final GeneratedColumn<String> buoyancy = GeneratedColumn<String>(
    'buoyancy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageReferenceMeta = const VerificationMeta(
    'imageReference',
  );
  @override
  late final GeneratedColumn<String> imageReference = GeneratedColumn<String>(
    'image_reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedVersionMeta = const VerificationMeta(
    'seedVersion',
  );
  @override
  late final GeneratedColumn<int> seedVersion = GeneratedColumn<int>(
    'seed_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retiredAtMeta = const VerificationMeta(
    'retiredAt',
  );
  @override
  late final GeneratedColumn<int> retiredAt = GeneratedColumn<int>(
    'retired_at',
    aliasedName,
    true,
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
    lureModelId,
    variantName,
    colorName,
    manufacturerColorCode,
    lengthMillimeters,
    weightGrams,
    minRunningDepthMillimeters,
    maxRunningDepthMillimeters,
    buoyancy,
    imageReference,
    searchText,
    seedVersion,
    retiredAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lure_variants';
  @override
  VerificationContext validateIntegrity(
    Insertable<LureVariantEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lure_model_id')) {
      context.handle(
        _lureModelIdMeta,
        lureModelId.isAcceptableOrUnknown(
          data['lure_model_id']!,
          _lureModelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lureModelIdMeta);
    }
    if (data.containsKey('variant_name')) {
      context.handle(
        _variantNameMeta,
        variantName.isAcceptableOrUnknown(
          data['variant_name']!,
          _variantNameMeta,
        ),
      );
    }
    if (data.containsKey('color_name')) {
      context.handle(
        _colorNameMeta,
        colorName.isAcceptableOrUnknown(data['color_name']!, _colorNameMeta),
      );
    }
    if (data.containsKey('manufacturer_color_code')) {
      context.handle(
        _manufacturerColorCodeMeta,
        manufacturerColorCode.isAcceptableOrUnknown(
          data['manufacturer_color_code']!,
          _manufacturerColorCodeMeta,
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
    if (data.containsKey('weight_grams')) {
      context.handle(
        _weightGramsMeta,
        weightGrams.isAcceptableOrUnknown(
          data['weight_grams']!,
          _weightGramsMeta,
        ),
      );
    }
    if (data.containsKey('min_running_depth_millimeters')) {
      context.handle(
        _minRunningDepthMillimetersMeta,
        minRunningDepthMillimeters.isAcceptableOrUnknown(
          data['min_running_depth_millimeters']!,
          _minRunningDepthMillimetersMeta,
        ),
      );
    }
    if (data.containsKey('max_running_depth_millimeters')) {
      context.handle(
        _maxRunningDepthMillimetersMeta,
        maxRunningDepthMillimeters.isAcceptableOrUnknown(
          data['max_running_depth_millimeters']!,
          _maxRunningDepthMillimetersMeta,
        ),
      );
    }
    if (data.containsKey('buoyancy')) {
      context.handle(
        _buoyancyMeta,
        buoyancy.isAcceptableOrUnknown(data['buoyancy']!, _buoyancyMeta),
      );
    }
    if (data.containsKey('image_reference')) {
      context.handle(
        _imageReferenceMeta,
        imageReference.isAcceptableOrUnknown(
          data['image_reference']!,
          _imageReferenceMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
      );
    } else if (isInserting) {
      context.missing(_searchTextMeta);
    }
    if (data.containsKey('seed_version')) {
      context.handle(
        _seedVersionMeta,
        seedVersion.isAcceptableOrUnknown(
          data['seed_version']!,
          _seedVersionMeta,
        ),
      );
    }
    if (data.containsKey('retired_at')) {
      context.handle(
        _retiredAtMeta,
        retiredAt.isAcceptableOrUnknown(data['retired_at']!, _retiredAtMeta),
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
  LureVariantEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LureVariantEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lureModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lure_model_id'],
      )!,
      variantName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_name'],
      ),
      colorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_name'],
      ),
      manufacturerColorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer_color_code'],
      ),
      lengthMillimeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length_millimeters'],
      ),
      weightGrams: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight_grams'],
      ),
      minRunningDepthMillimeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_running_depth_millimeters'],
      ),
      maxRunningDepthMillimeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_running_depth_millimeters'],
      ),
      buoyancy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}buoyancy'],
      ),
      imageReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_reference'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      seedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed_version'],
      ),
      retiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retired_at'],
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
  $LureVariantsTable createAlias(String alias) {
    return $LureVariantsTable(attachedDatabase, alias);
  }
}

class LureVariantEntity extends DataClass
    implements Insertable<LureVariantEntity> {
  final String id;
  final String lureModelId;
  final String? variantName;
  final String? colorName;
  final String? manufacturerColorCode;
  final int? lengthMillimeters;
  final int? weightGrams;
  final int? minRunningDepthMillimeters;
  final int? maxRunningDepthMillimeters;
  final String? buoyancy;
  final String? imageReference;
  final String searchText;
  final int? seedVersion;
  final int? retiredAt;
  final int createdAt;
  final int updatedAt;
  const LureVariantEntity({
    required this.id,
    required this.lureModelId,
    this.variantName,
    this.colorName,
    this.manufacturerColorCode,
    this.lengthMillimeters,
    this.weightGrams,
    this.minRunningDepthMillimeters,
    this.maxRunningDepthMillimeters,
    this.buoyancy,
    this.imageReference,
    required this.searchText,
    this.seedVersion,
    this.retiredAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lure_model_id'] = Variable<String>(lureModelId);
    if (!nullToAbsent || variantName != null) {
      map['variant_name'] = Variable<String>(variantName);
    }
    if (!nullToAbsent || colorName != null) {
      map['color_name'] = Variable<String>(colorName);
    }
    if (!nullToAbsent || manufacturerColorCode != null) {
      map['manufacturer_color_code'] = Variable<String>(manufacturerColorCode);
    }
    if (!nullToAbsent || lengthMillimeters != null) {
      map['length_millimeters'] = Variable<int>(lengthMillimeters);
    }
    if (!nullToAbsent || weightGrams != null) {
      map['weight_grams'] = Variable<int>(weightGrams);
    }
    if (!nullToAbsent || minRunningDepthMillimeters != null) {
      map['min_running_depth_millimeters'] = Variable<int>(
        minRunningDepthMillimeters,
      );
    }
    if (!nullToAbsent || maxRunningDepthMillimeters != null) {
      map['max_running_depth_millimeters'] = Variable<int>(
        maxRunningDepthMillimeters,
      );
    }
    if (!nullToAbsent || buoyancy != null) {
      map['buoyancy'] = Variable<String>(buoyancy);
    }
    if (!nullToAbsent || imageReference != null) {
      map['image_reference'] = Variable<String>(imageReference);
    }
    map['search_text'] = Variable<String>(searchText);
    if (!nullToAbsent || seedVersion != null) {
      map['seed_version'] = Variable<int>(seedVersion);
    }
    if (!nullToAbsent || retiredAt != null) {
      map['retired_at'] = Variable<int>(retiredAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LureVariantsCompanion toCompanion(bool nullToAbsent) {
    return LureVariantsCompanion(
      id: Value(id),
      lureModelId: Value(lureModelId),
      variantName: variantName == null && nullToAbsent
          ? const Value.absent()
          : Value(variantName),
      colorName: colorName == null && nullToAbsent
          ? const Value.absent()
          : Value(colorName),
      manufacturerColorCode: manufacturerColorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(manufacturerColorCode),
      lengthMillimeters: lengthMillimeters == null && nullToAbsent
          ? const Value.absent()
          : Value(lengthMillimeters),
      weightGrams: weightGrams == null && nullToAbsent
          ? const Value.absent()
          : Value(weightGrams),
      minRunningDepthMillimeters:
          minRunningDepthMillimeters == null && nullToAbsent
          ? const Value.absent()
          : Value(minRunningDepthMillimeters),
      maxRunningDepthMillimeters:
          maxRunningDepthMillimeters == null && nullToAbsent
          ? const Value.absent()
          : Value(maxRunningDepthMillimeters),
      buoyancy: buoyancy == null && nullToAbsent
          ? const Value.absent()
          : Value(buoyancy),
      imageReference: imageReference == null && nullToAbsent
          ? const Value.absent()
          : Value(imageReference),
      searchText: Value(searchText),
      seedVersion: seedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(seedVersion),
      retiredAt: retiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(retiredAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LureVariantEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LureVariantEntity(
      id: serializer.fromJson<String>(json['id']),
      lureModelId: serializer.fromJson<String>(json['lureModelId']),
      variantName: serializer.fromJson<String?>(json['variantName']),
      colorName: serializer.fromJson<String?>(json['colorName']),
      manufacturerColorCode: serializer.fromJson<String?>(
        json['manufacturerColorCode'],
      ),
      lengthMillimeters: serializer.fromJson<int?>(json['lengthMillimeters']),
      weightGrams: serializer.fromJson<int?>(json['weightGrams']),
      minRunningDepthMillimeters: serializer.fromJson<int?>(
        json['minRunningDepthMillimeters'],
      ),
      maxRunningDepthMillimeters: serializer.fromJson<int?>(
        json['maxRunningDepthMillimeters'],
      ),
      buoyancy: serializer.fromJson<String?>(json['buoyancy']),
      imageReference: serializer.fromJson<String?>(json['imageReference']),
      searchText: serializer.fromJson<String>(json['searchText']),
      seedVersion: serializer.fromJson<int?>(json['seedVersion']),
      retiredAt: serializer.fromJson<int?>(json['retiredAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lureModelId': serializer.toJson<String>(lureModelId),
      'variantName': serializer.toJson<String?>(variantName),
      'colorName': serializer.toJson<String?>(colorName),
      'manufacturerColorCode': serializer.toJson<String?>(
        manufacturerColorCode,
      ),
      'lengthMillimeters': serializer.toJson<int?>(lengthMillimeters),
      'weightGrams': serializer.toJson<int?>(weightGrams),
      'minRunningDepthMillimeters': serializer.toJson<int?>(
        minRunningDepthMillimeters,
      ),
      'maxRunningDepthMillimeters': serializer.toJson<int?>(
        maxRunningDepthMillimeters,
      ),
      'buoyancy': serializer.toJson<String?>(buoyancy),
      'imageReference': serializer.toJson<String?>(imageReference),
      'searchText': serializer.toJson<String>(searchText),
      'seedVersion': serializer.toJson<int?>(seedVersion),
      'retiredAt': serializer.toJson<int?>(retiredAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LureVariantEntity copyWith({
    String? id,
    String? lureModelId,
    Value<String?> variantName = const Value.absent(),
    Value<String?> colorName = const Value.absent(),
    Value<String?> manufacturerColorCode = const Value.absent(),
    Value<int?> lengthMillimeters = const Value.absent(),
    Value<int?> weightGrams = const Value.absent(),
    Value<int?> minRunningDepthMillimeters = const Value.absent(),
    Value<int?> maxRunningDepthMillimeters = const Value.absent(),
    Value<String?> buoyancy = const Value.absent(),
    Value<String?> imageReference = const Value.absent(),
    String? searchText,
    Value<int?> seedVersion = const Value.absent(),
    Value<int?> retiredAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => LureVariantEntity(
    id: id ?? this.id,
    lureModelId: lureModelId ?? this.lureModelId,
    variantName: variantName.present ? variantName.value : this.variantName,
    colorName: colorName.present ? colorName.value : this.colorName,
    manufacturerColorCode: manufacturerColorCode.present
        ? manufacturerColorCode.value
        : this.manufacturerColorCode,
    lengthMillimeters: lengthMillimeters.present
        ? lengthMillimeters.value
        : this.lengthMillimeters,
    weightGrams: weightGrams.present ? weightGrams.value : this.weightGrams,
    minRunningDepthMillimeters: minRunningDepthMillimeters.present
        ? minRunningDepthMillimeters.value
        : this.minRunningDepthMillimeters,
    maxRunningDepthMillimeters: maxRunningDepthMillimeters.present
        ? maxRunningDepthMillimeters.value
        : this.maxRunningDepthMillimeters,
    buoyancy: buoyancy.present ? buoyancy.value : this.buoyancy,
    imageReference: imageReference.present
        ? imageReference.value
        : this.imageReference,
    searchText: searchText ?? this.searchText,
    seedVersion: seedVersion.present ? seedVersion.value : this.seedVersion,
    retiredAt: retiredAt.present ? retiredAt.value : this.retiredAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LureVariantEntity copyWithCompanion(LureVariantsCompanion data) {
    return LureVariantEntity(
      id: data.id.present ? data.id.value : this.id,
      lureModelId: data.lureModelId.present
          ? data.lureModelId.value
          : this.lureModelId,
      variantName: data.variantName.present
          ? data.variantName.value
          : this.variantName,
      colorName: data.colorName.present ? data.colorName.value : this.colorName,
      manufacturerColorCode: data.manufacturerColorCode.present
          ? data.manufacturerColorCode.value
          : this.manufacturerColorCode,
      lengthMillimeters: data.lengthMillimeters.present
          ? data.lengthMillimeters.value
          : this.lengthMillimeters,
      weightGrams: data.weightGrams.present
          ? data.weightGrams.value
          : this.weightGrams,
      minRunningDepthMillimeters: data.minRunningDepthMillimeters.present
          ? data.minRunningDepthMillimeters.value
          : this.minRunningDepthMillimeters,
      maxRunningDepthMillimeters: data.maxRunningDepthMillimeters.present
          ? data.maxRunningDepthMillimeters.value
          : this.maxRunningDepthMillimeters,
      buoyancy: data.buoyancy.present ? data.buoyancy.value : this.buoyancy,
      imageReference: data.imageReference.present
          ? data.imageReference.value
          : this.imageReference,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      seedVersion: data.seedVersion.present
          ? data.seedVersion.value
          : this.seedVersion,
      retiredAt: data.retiredAt.present ? data.retiredAt.value : this.retiredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LureVariantEntity(')
          ..write('id: $id, ')
          ..write('lureModelId: $lureModelId, ')
          ..write('variantName: $variantName, ')
          ..write('colorName: $colorName, ')
          ..write('manufacturerColorCode: $manufacturerColorCode, ')
          ..write('lengthMillimeters: $lengthMillimeters, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('minRunningDepthMillimeters: $minRunningDepthMillimeters, ')
          ..write('maxRunningDepthMillimeters: $maxRunningDepthMillimeters, ')
          ..write('buoyancy: $buoyancy, ')
          ..write('imageReference: $imageReference, ')
          ..write('searchText: $searchText, ')
          ..write('seedVersion: $seedVersion, ')
          ..write('retiredAt: $retiredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lureModelId,
    variantName,
    colorName,
    manufacturerColorCode,
    lengthMillimeters,
    weightGrams,
    minRunningDepthMillimeters,
    maxRunningDepthMillimeters,
    buoyancy,
    imageReference,
    searchText,
    seedVersion,
    retiredAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LureVariantEntity &&
          other.id == this.id &&
          other.lureModelId == this.lureModelId &&
          other.variantName == this.variantName &&
          other.colorName == this.colorName &&
          other.manufacturerColorCode == this.manufacturerColorCode &&
          other.lengthMillimeters == this.lengthMillimeters &&
          other.weightGrams == this.weightGrams &&
          other.minRunningDepthMillimeters == this.minRunningDepthMillimeters &&
          other.maxRunningDepthMillimeters == this.maxRunningDepthMillimeters &&
          other.buoyancy == this.buoyancy &&
          other.imageReference == this.imageReference &&
          other.searchText == this.searchText &&
          other.seedVersion == this.seedVersion &&
          other.retiredAt == this.retiredAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LureVariantsCompanion extends UpdateCompanion<LureVariantEntity> {
  final Value<String> id;
  final Value<String> lureModelId;
  final Value<String?> variantName;
  final Value<String?> colorName;
  final Value<String?> manufacturerColorCode;
  final Value<int?> lengthMillimeters;
  final Value<int?> weightGrams;
  final Value<int?> minRunningDepthMillimeters;
  final Value<int?> maxRunningDepthMillimeters;
  final Value<String?> buoyancy;
  final Value<String?> imageReference;
  final Value<String> searchText;
  final Value<int?> seedVersion;
  final Value<int?> retiredAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LureVariantsCompanion({
    this.id = const Value.absent(),
    this.lureModelId = const Value.absent(),
    this.variantName = const Value.absent(),
    this.colorName = const Value.absent(),
    this.manufacturerColorCode = const Value.absent(),
    this.lengthMillimeters = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.minRunningDepthMillimeters = const Value.absent(),
    this.maxRunningDepthMillimeters = const Value.absent(),
    this.buoyancy = const Value.absent(),
    this.imageReference = const Value.absent(),
    this.searchText = const Value.absent(),
    this.seedVersion = const Value.absent(),
    this.retiredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LureVariantsCompanion.insert({
    required String id,
    required String lureModelId,
    this.variantName = const Value.absent(),
    this.colorName = const Value.absent(),
    this.manufacturerColorCode = const Value.absent(),
    this.lengthMillimeters = const Value.absent(),
    this.weightGrams = const Value.absent(),
    this.minRunningDepthMillimeters = const Value.absent(),
    this.maxRunningDepthMillimeters = const Value.absent(),
    this.buoyancy = const Value.absent(),
    this.imageReference = const Value.absent(),
    required String searchText,
    this.seedVersion = const Value.absent(),
    this.retiredAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lureModelId = Value(lureModelId),
       searchText = Value(searchText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LureVariantEntity> custom({
    Expression<String>? id,
    Expression<String>? lureModelId,
    Expression<String>? variantName,
    Expression<String>? colorName,
    Expression<String>? manufacturerColorCode,
    Expression<int>? lengthMillimeters,
    Expression<int>? weightGrams,
    Expression<int>? minRunningDepthMillimeters,
    Expression<int>? maxRunningDepthMillimeters,
    Expression<String>? buoyancy,
    Expression<String>? imageReference,
    Expression<String>? searchText,
    Expression<int>? seedVersion,
    Expression<int>? retiredAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lureModelId != null) 'lure_model_id': lureModelId,
      if (variantName != null) 'variant_name': variantName,
      if (colorName != null) 'color_name': colorName,
      if (manufacturerColorCode != null)
        'manufacturer_color_code': manufacturerColorCode,
      if (lengthMillimeters != null) 'length_millimeters': lengthMillimeters,
      if (weightGrams != null) 'weight_grams': weightGrams,
      if (minRunningDepthMillimeters != null)
        'min_running_depth_millimeters': minRunningDepthMillimeters,
      if (maxRunningDepthMillimeters != null)
        'max_running_depth_millimeters': maxRunningDepthMillimeters,
      if (buoyancy != null) 'buoyancy': buoyancy,
      if (imageReference != null) 'image_reference': imageReference,
      if (searchText != null) 'search_text': searchText,
      if (seedVersion != null) 'seed_version': seedVersion,
      if (retiredAt != null) 'retired_at': retiredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LureVariantsCompanion copyWith({
    Value<String>? id,
    Value<String>? lureModelId,
    Value<String?>? variantName,
    Value<String?>? colorName,
    Value<String?>? manufacturerColorCode,
    Value<int?>? lengthMillimeters,
    Value<int?>? weightGrams,
    Value<int?>? minRunningDepthMillimeters,
    Value<int?>? maxRunningDepthMillimeters,
    Value<String?>? buoyancy,
    Value<String?>? imageReference,
    Value<String>? searchText,
    Value<int?>? seedVersion,
    Value<int?>? retiredAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LureVariantsCompanion(
      id: id ?? this.id,
      lureModelId: lureModelId ?? this.lureModelId,
      variantName: variantName ?? this.variantName,
      colorName: colorName ?? this.colorName,
      manufacturerColorCode:
          manufacturerColorCode ?? this.manufacturerColorCode,
      lengthMillimeters: lengthMillimeters ?? this.lengthMillimeters,
      weightGrams: weightGrams ?? this.weightGrams,
      minRunningDepthMillimeters:
          minRunningDepthMillimeters ?? this.minRunningDepthMillimeters,
      maxRunningDepthMillimeters:
          maxRunningDepthMillimeters ?? this.maxRunningDepthMillimeters,
      buoyancy: buoyancy ?? this.buoyancy,
      imageReference: imageReference ?? this.imageReference,
      searchText: searchText ?? this.searchText,
      seedVersion: seedVersion ?? this.seedVersion,
      retiredAt: retiredAt ?? this.retiredAt,
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
    if (lureModelId.present) {
      map['lure_model_id'] = Variable<String>(lureModelId.value);
    }
    if (variantName.present) {
      map['variant_name'] = Variable<String>(variantName.value);
    }
    if (colorName.present) {
      map['color_name'] = Variable<String>(colorName.value);
    }
    if (manufacturerColorCode.present) {
      map['manufacturer_color_code'] = Variable<String>(
        manufacturerColorCode.value,
      );
    }
    if (lengthMillimeters.present) {
      map['length_millimeters'] = Variable<int>(lengthMillimeters.value);
    }
    if (weightGrams.present) {
      map['weight_grams'] = Variable<int>(weightGrams.value);
    }
    if (minRunningDepthMillimeters.present) {
      map['min_running_depth_millimeters'] = Variable<int>(
        minRunningDepthMillimeters.value,
      );
    }
    if (maxRunningDepthMillimeters.present) {
      map['max_running_depth_millimeters'] = Variable<int>(
        maxRunningDepthMillimeters.value,
      );
    }
    if (buoyancy.present) {
      map['buoyancy'] = Variable<String>(buoyancy.value);
    }
    if (imageReference.present) {
      map['image_reference'] = Variable<String>(imageReference.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (seedVersion.present) {
      map['seed_version'] = Variable<int>(seedVersion.value);
    }
    if (retiredAt.present) {
      map['retired_at'] = Variable<int>(retiredAt.value);
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
    return (StringBuffer('LureVariantsCompanion(')
          ..write('id: $id, ')
          ..write('lureModelId: $lureModelId, ')
          ..write('variantName: $variantName, ')
          ..write('colorName: $colorName, ')
          ..write('manufacturerColorCode: $manufacturerColorCode, ')
          ..write('lengthMillimeters: $lengthMillimeters, ')
          ..write('weightGrams: $weightGrams, ')
          ..write('minRunningDepthMillimeters: $minRunningDepthMillimeters, ')
          ..write('maxRunningDepthMillimeters: $maxRunningDepthMillimeters, ')
          ..write('buoyancy: $buoyancy, ')
          ..write('imageReference: $imageReference, ')
          ..write('searchText: $searchText, ')
          ..write('seedVersion: $seedVersion, ')
          ..write('retiredAt: $retiredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
  static const VerificationMeta _lureVariantIdMeta = const VerificationMeta(
    'lureVariantId',
  );
  @override
  late final GeneratedColumn<String> lureVariantId = GeneratedColumn<String>(
    'lure_variant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lure_variants (id) ON DELETE RESTRICT',
    ),
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
    lureVariantId,
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
    if (data.containsKey('lure_variant_id')) {
      context.handle(
        _lureVariantIdMeta,
        lureVariantId.isAcceptableOrUnknown(
          data['lure_variant_id']!,
          _lureVariantIdMeta,
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
      lureVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lure_variant_id'],
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
  final String? lureVariantId;
  final int createdAt;
  final int updatedAt;
  const CatchEntity({
    required this.id,
    required this.fishingSpotId,
    required this.species,
    required this.caughtAt,
    this.weightGrams,
    this.lengthMillimeters,
    this.lureVariantId,
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
    if (!nullToAbsent || lureVariantId != null) {
      map['lure_variant_id'] = Variable<String>(lureVariantId);
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
      lureVariantId: lureVariantId == null && nullToAbsent
          ? const Value.absent()
          : Value(lureVariantId),
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
      lureVariantId: serializer.fromJson<String?>(json['lureVariantId']),
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
      'lureVariantId': serializer.toJson<String?>(lureVariantId),
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
    Value<String?> lureVariantId = const Value.absent(),
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
    lureVariantId: lureVariantId.present
        ? lureVariantId.value
        : this.lureVariantId,
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
      lureVariantId: data.lureVariantId.present
          ? data.lureVariantId.value
          : this.lureVariantId,
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
          ..write('lureVariantId: $lureVariantId, ')
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
    lureVariantId,
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
          other.lureVariantId == this.lureVariantId &&
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
  final Value<String?> lureVariantId;
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
    this.lureVariantId = const Value.absent(),
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
    this.lureVariantId = const Value.absent(),
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
    Expression<String>? lureVariantId,
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
      if (lureVariantId != null) 'lure_variant_id': lureVariantId,
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
    Value<String?>? lureVariantId,
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
      lureVariantId: lureVariantId ?? this.lureVariantId,
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
    if (lureVariantId.present) {
      map['lure_variant_id'] = Variable<String>(lureVariantId.value);
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
          ..write('lureVariantId: $lureVariantId, ')
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

class $TackleBoxEntriesTable extends TackleBoxEntries
    with TableInfo<$TackleBoxEntriesTable, TackleBoxEntryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TackleBoxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lureVariantIdMeta = const VerificationMeta(
    'lureVariantId',
  );
  @override
  late final GeneratedColumn<String> lureVariantId = GeneratedColumn<String>(
    'lure_variant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lure_variants (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _personalPhotoRelativePathMeta =
      const VerificationMeta('personalPhotoRelativePath');
  @override
  late final GeneratedColumn<String> personalPhotoRelativePath =
      GeneratedColumn<String>(
        'personal_photo_relative_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
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
    lureVariantId,
    personalPhotoRelativePath,
    addedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tackle_box_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TackleBoxEntryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lure_variant_id')) {
      context.handle(
        _lureVariantIdMeta,
        lureVariantId.isAcceptableOrUnknown(
          data['lure_variant_id']!,
          _lureVariantIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lureVariantIdMeta);
    }
    if (data.containsKey('personal_photo_relative_path')) {
      context.handle(
        _personalPhotoRelativePathMeta,
        personalPhotoRelativePath.isAcceptableOrUnknown(
          data['personal_photo_relative_path']!,
          _personalPhotoRelativePathMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {lureVariantId},
  ];
  @override
  TackleBoxEntryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TackleBoxEntryEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lureVariantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lure_variant_id'],
      )!,
      personalPhotoRelativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personal_photo_relative_path'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
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
  $TackleBoxEntriesTable createAlias(String alias) {
    return $TackleBoxEntriesTable(attachedDatabase, alias);
  }
}

class TackleBoxEntryEntity extends DataClass
    implements Insertable<TackleBoxEntryEntity> {
  final String id;
  final String lureVariantId;
  final String? personalPhotoRelativePath;
  final int addedAt;
  final int createdAt;
  final int updatedAt;
  const TackleBoxEntryEntity({
    required this.id,
    required this.lureVariantId,
    this.personalPhotoRelativePath,
    required this.addedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lure_variant_id'] = Variable<String>(lureVariantId);
    if (!nullToAbsent || personalPhotoRelativePath != null) {
      map['personal_photo_relative_path'] = Variable<String>(
        personalPhotoRelativePath,
      );
    }
    map['added_at'] = Variable<int>(addedAt);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TackleBoxEntriesCompanion toCompanion(bool nullToAbsent) {
    return TackleBoxEntriesCompanion(
      id: Value(id),
      lureVariantId: Value(lureVariantId),
      personalPhotoRelativePath:
          personalPhotoRelativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(personalPhotoRelativePath),
      addedAt: Value(addedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TackleBoxEntryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TackleBoxEntryEntity(
      id: serializer.fromJson<String>(json['id']),
      lureVariantId: serializer.fromJson<String>(json['lureVariantId']),
      personalPhotoRelativePath: serializer.fromJson<String?>(
        json['personalPhotoRelativePath'],
      ),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lureVariantId': serializer.toJson<String>(lureVariantId),
      'personalPhotoRelativePath': serializer.toJson<String?>(
        personalPhotoRelativePath,
      ),
      'addedAt': serializer.toJson<int>(addedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TackleBoxEntryEntity copyWith({
    String? id,
    String? lureVariantId,
    Value<String?> personalPhotoRelativePath = const Value.absent(),
    int? addedAt,
    int? createdAt,
    int? updatedAt,
  }) => TackleBoxEntryEntity(
    id: id ?? this.id,
    lureVariantId: lureVariantId ?? this.lureVariantId,
    personalPhotoRelativePath: personalPhotoRelativePath.present
        ? personalPhotoRelativePath.value
        : this.personalPhotoRelativePath,
    addedAt: addedAt ?? this.addedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TackleBoxEntryEntity copyWithCompanion(TackleBoxEntriesCompanion data) {
    return TackleBoxEntryEntity(
      id: data.id.present ? data.id.value : this.id,
      lureVariantId: data.lureVariantId.present
          ? data.lureVariantId.value
          : this.lureVariantId,
      personalPhotoRelativePath: data.personalPhotoRelativePath.present
          ? data.personalPhotoRelativePath.value
          : this.personalPhotoRelativePath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TackleBoxEntryEntity(')
          ..write('id: $id, ')
          ..write('lureVariantId: $lureVariantId, ')
          ..write('personalPhotoRelativePath: $personalPhotoRelativePath, ')
          ..write('addedAt: $addedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lureVariantId,
    personalPhotoRelativePath,
    addedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TackleBoxEntryEntity &&
          other.id == this.id &&
          other.lureVariantId == this.lureVariantId &&
          other.personalPhotoRelativePath == this.personalPhotoRelativePath &&
          other.addedAt == this.addedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TackleBoxEntriesCompanion extends UpdateCompanion<TackleBoxEntryEntity> {
  final Value<String> id;
  final Value<String> lureVariantId;
  final Value<String?> personalPhotoRelativePath;
  final Value<int> addedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TackleBoxEntriesCompanion({
    this.id = const Value.absent(),
    this.lureVariantId = const Value.absent(),
    this.personalPhotoRelativePath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TackleBoxEntriesCompanion.insert({
    required String id,
    required String lureVariantId,
    this.personalPhotoRelativePath = const Value.absent(),
    required int addedAt,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lureVariantId = Value(lureVariantId),
       addedAt = Value(addedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TackleBoxEntryEntity> custom({
    Expression<String>? id,
    Expression<String>? lureVariantId,
    Expression<String>? personalPhotoRelativePath,
    Expression<int>? addedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lureVariantId != null) 'lure_variant_id': lureVariantId,
      if (personalPhotoRelativePath != null)
        'personal_photo_relative_path': personalPhotoRelativePath,
      if (addedAt != null) 'added_at': addedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TackleBoxEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? lureVariantId,
    Value<String?>? personalPhotoRelativePath,
    Value<int>? addedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TackleBoxEntriesCompanion(
      id: id ?? this.id,
      lureVariantId: lureVariantId ?? this.lureVariantId,
      personalPhotoRelativePath:
          personalPhotoRelativePath ?? this.personalPhotoRelativePath,
      addedAt: addedAt ?? this.addedAt,
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
    if (lureVariantId.present) {
      map['lure_variant_id'] = Variable<String>(lureVariantId.value);
    }
    if (personalPhotoRelativePath.present) {
      map['personal_photo_relative_path'] = Variable<String>(
        personalPhotoRelativePath.value,
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
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
    return (StringBuffer('TackleBoxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('lureVariantId: $lureVariantId, ')
          ..write('personalPhotoRelativePath: $personalPhotoRelativePath, ')
          ..write('addedAt: $addedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FishingSpotsTable fishingSpots = $FishingSpotsTable(this);
  late final $LureModelsTable lureModels = $LureModelsTable(this);
  late final $LureVariantsTable lureVariants = $LureVariantsTable(this);
  late final $CatchesTable catches = $CatchesTable(this);
  late final $CatchPhotosTable catchPhotos = $CatchPhotosTable(this);
  late final $TackleBoxEntriesTable tackleBoxEntries = $TackleBoxEntriesTable(
    this,
  );
  late final Index catchPhotosCatchIdSort = Index(
    'catch_photos_catch_id_sort',
    'CREATE INDEX catch_photos_catch_id_sort ON catch_photos (catch_id, sort_order)',
  );
  late final Index lureModelsManufacturer = Index(
    'lure_models_manufacturer',
    'CREATE INDEX lure_models_manufacturer ON lure_models (manufacturer)',
  );
  late final Index lureModelsLureType = Index(
    'lure_models_lure_type',
    'CREATE INDEX lure_models_lure_type ON lure_models (lure_type)',
  );
  late final Index lureVariantsLureModelId = Index(
    'lure_variants_lure_model_id',
    'CREATE INDEX lure_variants_lure_model_id ON lure_variants (lure_model_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    fishingSpots,
    lureModels,
    lureVariants,
    catches,
    catchPhotos,
    tackleBoxEntries,
    catchPhotosCatchIdSort,
    lureModelsManufacturer,
    lureModelsLureType,
    lureVariantsLureModelId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lure_models',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lure_variants', kind: UpdateKind.delete)],
    ),
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
typedef $$LureModelsTableCreateCompanionBuilder =
    LureModelsCompanion Function({
      required String id,
      required String manufacturer,
      Value<String?> productFamily,
      required String modelName,
      required String lureType,
      Value<String?> defaultImageReference,
      required String searchText,
      Value<int?> seedVersion,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LureModelsTableUpdateCompanionBuilder =
    LureModelsCompanion Function({
      Value<String> id,
      Value<String> manufacturer,
      Value<String?> productFamily,
      Value<String> modelName,
      Value<String> lureType,
      Value<String?> defaultImageReference,
      Value<String> searchText,
      Value<int?> seedVersion,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$LureModelsTableReferences
    extends BaseReferences<_$AppDatabase, $LureModelsTable, LureModelEntity> {
  $$LureModelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LureVariantsTable, List<LureVariantEntity>>
  _lureVariantsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lureVariants,
    aliasName: 'lure_models__id__lure_variants__lure_model_id',
  );

  $$LureVariantsTableProcessedTableManager get lureVariantsRefs {
    final manager = $$LureVariantsTableTableManager(
      $_db,
      $_db.lureVariants,
    ).filter((f) => f.lureModelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_lureVariantsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LureModelsTableFilterComposer
    extends Composer<_$AppDatabase, $LureModelsTable> {
  $$LureModelsTableFilterComposer({
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

  ColumnFilters<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productFamily => $composableBuilder(
    column: $table.productFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lureType => $composableBuilder(
    column: $table.lureType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultImageReference => $composableBuilder(
    column: $table.defaultImageReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
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

  Expression<bool> lureVariantsRefs(
    Expression<bool> Function($$LureVariantsTableFilterComposer f) f,
  ) {
    final $$LureVariantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.lureModelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableFilterComposer(
            $db: $db,
            $table: $db.lureVariants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LureModelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LureModelsTable> {
  $$LureModelsTableOrderingComposer({
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

  ColumnOrderings<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productFamily => $composableBuilder(
    column: $table.productFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelName => $composableBuilder(
    column: $table.modelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lureType => $composableBuilder(
    column: $table.lureType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultImageReference => $composableBuilder(
    column: $table.defaultImageReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
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
}

class $$LureModelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LureModelsTable> {
  $$LureModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productFamily => $composableBuilder(
    column: $table.productFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelName =>
      $composableBuilder(column: $table.modelName, builder: (column) => column);

  GeneratedColumn<String> get lureType =>
      $composableBuilder(column: $table.lureType, builder: (column) => column);

  GeneratedColumn<String> get defaultImageReference => $composableBuilder(
    column: $table.defaultImageReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> lureVariantsRefs<T extends Object>(
    Expression<T> Function($$LureVariantsTableAnnotationComposer a) f,
  ) {
    final $$LureVariantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.lureModelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableAnnotationComposer(
            $db: $db,
            $table: $db.lureVariants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LureModelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LureModelsTable,
          LureModelEntity,
          $$LureModelsTableFilterComposer,
          $$LureModelsTableOrderingComposer,
          $$LureModelsTableAnnotationComposer,
          $$LureModelsTableCreateCompanionBuilder,
          $$LureModelsTableUpdateCompanionBuilder,
          (LureModelEntity, $$LureModelsTableReferences),
          LureModelEntity,
          PrefetchHooks Function({bool lureVariantsRefs})
        > {
  $$LureModelsTableTableManager(_$AppDatabase db, $LureModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LureModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LureModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LureModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> manufacturer = const Value.absent(),
                Value<String?> productFamily = const Value.absent(),
                Value<String> modelName = const Value.absent(),
                Value<String> lureType = const Value.absent(),
                Value<String?> defaultImageReference = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int?> seedVersion = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LureModelsCompanion(
                id: id,
                manufacturer: manufacturer,
                productFamily: productFamily,
                modelName: modelName,
                lureType: lureType,
                defaultImageReference: defaultImageReference,
                searchText: searchText,
                seedVersion: seedVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String manufacturer,
                Value<String?> productFamily = const Value.absent(),
                required String modelName,
                required String lureType,
                Value<String?> defaultImageReference = const Value.absent(),
                required String searchText,
                Value<int?> seedVersion = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LureModelsCompanion.insert(
                id: id,
                manufacturer: manufacturer,
                productFamily: productFamily,
                modelName: modelName,
                lureType: lureType,
                defaultImageReference: defaultImageReference,
                searchText: searchText,
                seedVersion: seedVersion,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LureModelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lureVariantsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (lureVariantsRefs) db.lureVariants],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lureVariantsRefs)
                    await $_getPrefetchedData<
                      LureModelEntity,
                      $LureModelsTable,
                      LureVariantEntity
                    >(
                      currentTable: table,
                      referencedTable: $$LureModelsTableReferences
                          ._lureVariantsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LureModelsTableReferences(
                            db,
                            table,
                            p0,
                          ).lureVariantsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.lureModelId == item.id,
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

typedef $$LureModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LureModelsTable,
      LureModelEntity,
      $$LureModelsTableFilterComposer,
      $$LureModelsTableOrderingComposer,
      $$LureModelsTableAnnotationComposer,
      $$LureModelsTableCreateCompanionBuilder,
      $$LureModelsTableUpdateCompanionBuilder,
      (LureModelEntity, $$LureModelsTableReferences),
      LureModelEntity,
      PrefetchHooks Function({bool lureVariantsRefs})
    >;
typedef $$LureVariantsTableCreateCompanionBuilder =
    LureVariantsCompanion Function({
      required String id,
      required String lureModelId,
      Value<String?> variantName,
      Value<String?> colorName,
      Value<String?> manufacturerColorCode,
      Value<int?> lengthMillimeters,
      Value<int?> weightGrams,
      Value<int?> minRunningDepthMillimeters,
      Value<int?> maxRunningDepthMillimeters,
      Value<String?> buoyancy,
      Value<String?> imageReference,
      required String searchText,
      Value<int?> seedVersion,
      Value<int?> retiredAt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LureVariantsTableUpdateCompanionBuilder =
    LureVariantsCompanion Function({
      Value<String> id,
      Value<String> lureModelId,
      Value<String?> variantName,
      Value<String?> colorName,
      Value<String?> manufacturerColorCode,
      Value<int?> lengthMillimeters,
      Value<int?> weightGrams,
      Value<int?> minRunningDepthMillimeters,
      Value<int?> maxRunningDepthMillimeters,
      Value<String?> buoyancy,
      Value<String?> imageReference,
      Value<String> searchText,
      Value<int?> seedVersion,
      Value<int?> retiredAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$LureVariantsTableReferences
    extends
        BaseReferences<_$AppDatabase, $LureVariantsTable, LureVariantEntity> {
  $$LureVariantsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LureModelsTable _lureModelIdTable(_$AppDatabase db) => db.lureModels
      .createAlias('lure_variants__lure_model_id__lure_models__id');

  $$LureModelsTableProcessedTableManager get lureModelId {
    final $_column = $_itemColumn<String>('lure_model_id')!;

    final manager = $$LureModelsTableTableManager(
      $_db,
      $_db.lureModels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lureModelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CatchesTable, List<CatchEntity>>
  _catchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.catches,
    aliasName: 'lure_variants__id__catches__lure_variant_id',
  );

  $$CatchesTableProcessedTableManager get catchesRefs {
    final manager = $$CatchesTableTableManager(
      $_db,
      $_db.catches,
    ).filter((f) => f.lureVariantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_catchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TackleBoxEntriesTable, List<TackleBoxEntryEntity>>
  _tackleBoxEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tackleBoxEntries,
    aliasName: 'lure_variants__id__tackle_box_entries__lure_variant_id',
  );

  $$TackleBoxEntriesTableProcessedTableManager get tackleBoxEntriesRefs {
    final manager = $$TackleBoxEntriesTableTableManager(
      $_db,
      $_db.tackleBoxEntries,
    ).filter((f) => f.lureVariantId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _tackleBoxEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LureVariantsTableFilterComposer
    extends Composer<_$AppDatabase, $LureVariantsTable> {
  $$LureVariantsTableFilterComposer({
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

  ColumnFilters<String> get variantName => $composableBuilder(
    column: $table.variantName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorName => $composableBuilder(
    column: $table.colorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manufacturerColorCode => $composableBuilder(
    column: $table.manufacturerColorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minRunningDepthMillimeters => $composableBuilder(
    column: $table.minRunningDepthMillimeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRunningDepthMillimeters => $composableBuilder(
    column: $table.maxRunningDepthMillimeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get buoyancy => $composableBuilder(
    column: $table.buoyancy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retiredAt => $composableBuilder(
    column: $table.retiredAt,
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

  $$LureModelsTableFilterComposer get lureModelId {
    final $$LureModelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureModelId,
      referencedTable: $db.lureModels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureModelsTableFilterComposer(
            $db: $db,
            $table: $db.lureModels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> catchesRefs(
    Expression<bool> Function($$CatchesTableFilterComposer f) f,
  ) {
    final $$CatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.lureVariantId,
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

  Expression<bool> tackleBoxEntriesRefs(
    Expression<bool> Function($$TackleBoxEntriesTableFilterComposer f) f,
  ) {
    final $$TackleBoxEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tackleBoxEntries,
      getReferencedColumn: (t) => t.lureVariantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TackleBoxEntriesTableFilterComposer(
            $db: $db,
            $table: $db.tackleBoxEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LureVariantsTableOrderingComposer
    extends Composer<_$AppDatabase, $LureVariantsTable> {
  $$LureVariantsTableOrderingComposer({
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

  ColumnOrderings<String> get variantName => $composableBuilder(
    column: $table.variantName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorName => $composableBuilder(
    column: $table.colorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manufacturerColorCode => $composableBuilder(
    column: $table.manufacturerColorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minRunningDepthMillimeters => $composableBuilder(
    column: $table.minRunningDepthMillimeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRunningDepthMillimeters => $composableBuilder(
    column: $table.maxRunningDepthMillimeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get buoyancy => $composableBuilder(
    column: $table.buoyancy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retiredAt => $composableBuilder(
    column: $table.retiredAt,
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

  $$LureModelsTableOrderingComposer get lureModelId {
    final $$LureModelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureModelId,
      referencedTable: $db.lureModels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureModelsTableOrderingComposer(
            $db: $db,
            $table: $db.lureModels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LureVariantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LureVariantsTable> {
  $$LureVariantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get variantName => $composableBuilder(
    column: $table.variantName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorName =>
      $composableBuilder(column: $table.colorName, builder: (column) => column);

  GeneratedColumn<String> get manufacturerColorCode => $composableBuilder(
    column: $table.manufacturerColorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lengthMillimeters => $composableBuilder(
    column: $table.lengthMillimeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weightGrams => $composableBuilder(
    column: $table.weightGrams,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minRunningDepthMillimeters => $composableBuilder(
    column: $table.minRunningDepthMillimeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxRunningDepthMillimeters => $composableBuilder(
    column: $table.maxRunningDepthMillimeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get buoyancy =>
      $composableBuilder(column: $table.buoyancy, builder: (column) => column);

  GeneratedColumn<String> get imageReference => $composableBuilder(
    column: $table.imageReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seedVersion => $composableBuilder(
    column: $table.seedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retiredAt =>
      $composableBuilder(column: $table.retiredAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LureModelsTableAnnotationComposer get lureModelId {
    final $$LureModelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureModelId,
      referencedTable: $db.lureModels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureModelsTableAnnotationComposer(
            $db: $db,
            $table: $db.lureModels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> catchesRefs<T extends Object>(
    Expression<T> Function($$CatchesTableAnnotationComposer a) f,
  ) {
    final $$CatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.catches,
      getReferencedColumn: (t) => t.lureVariantId,
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

  Expression<T> tackleBoxEntriesRefs<T extends Object>(
    Expression<T> Function($$TackleBoxEntriesTableAnnotationComposer a) f,
  ) {
    final $$TackleBoxEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tackleBoxEntries,
      getReferencedColumn: (t) => t.lureVariantId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TackleBoxEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.tackleBoxEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LureVariantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LureVariantsTable,
          LureVariantEntity,
          $$LureVariantsTableFilterComposer,
          $$LureVariantsTableOrderingComposer,
          $$LureVariantsTableAnnotationComposer,
          $$LureVariantsTableCreateCompanionBuilder,
          $$LureVariantsTableUpdateCompanionBuilder,
          (LureVariantEntity, $$LureVariantsTableReferences),
          LureVariantEntity,
          PrefetchHooks Function({
            bool lureModelId,
            bool catchesRefs,
            bool tackleBoxEntriesRefs,
          })
        > {
  $$LureVariantsTableTableManager(_$AppDatabase db, $LureVariantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LureVariantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LureVariantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LureVariantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lureModelId = const Value.absent(),
                Value<String?> variantName = const Value.absent(),
                Value<String?> colorName = const Value.absent(),
                Value<String?> manufacturerColorCode = const Value.absent(),
                Value<int?> lengthMillimeters = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> minRunningDepthMillimeters = const Value.absent(),
                Value<int?> maxRunningDepthMillimeters = const Value.absent(),
                Value<String?> buoyancy = const Value.absent(),
                Value<String?> imageReference = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<int?> seedVersion = const Value.absent(),
                Value<int?> retiredAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LureVariantsCompanion(
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
                imageReference: imageReference,
                searchText: searchText,
                seedVersion: seedVersion,
                retiredAt: retiredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lureModelId,
                Value<String?> variantName = const Value.absent(),
                Value<String?> colorName = const Value.absent(),
                Value<String?> manufacturerColorCode = const Value.absent(),
                Value<int?> lengthMillimeters = const Value.absent(),
                Value<int?> weightGrams = const Value.absent(),
                Value<int?> minRunningDepthMillimeters = const Value.absent(),
                Value<int?> maxRunningDepthMillimeters = const Value.absent(),
                Value<String?> buoyancy = const Value.absent(),
                Value<String?> imageReference = const Value.absent(),
                required String searchText,
                Value<int?> seedVersion = const Value.absent(),
                Value<int?> retiredAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LureVariantsCompanion.insert(
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
                imageReference: imageReference,
                searchText: searchText,
                seedVersion: seedVersion,
                retiredAt: retiredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LureVariantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                lureModelId = false,
                catchesRefs = false,
                tackleBoxEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (catchesRefs) db.catches,
                    if (tackleBoxEntriesRefs) db.tackleBoxEntries,
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
                        if (lureModelId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.lureModelId,
                                    referencedTable:
                                        $$LureVariantsTableReferences
                                            ._lureModelIdTable(db),
                                    referencedColumn:
                                        $$LureVariantsTableReferences
                                            ._lureModelIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (catchesRefs)
                        await $_getPrefetchedData<
                          LureVariantEntity,
                          $LureVariantsTable,
                          CatchEntity
                        >(
                          currentTable: table,
                          referencedTable: $$LureVariantsTableReferences
                              ._catchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LureVariantsTableReferences(
                                db,
                                table,
                                p0,
                              ).catchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lureVariantId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tackleBoxEntriesRefs)
                        await $_getPrefetchedData<
                          LureVariantEntity,
                          $LureVariantsTable,
                          TackleBoxEntryEntity
                        >(
                          currentTable: table,
                          referencedTable: $$LureVariantsTableReferences
                              ._tackleBoxEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LureVariantsTableReferences(
                                db,
                                table,
                                p0,
                              ).tackleBoxEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lureVariantId == item.id,
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

typedef $$LureVariantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LureVariantsTable,
      LureVariantEntity,
      $$LureVariantsTableFilterComposer,
      $$LureVariantsTableOrderingComposer,
      $$LureVariantsTableAnnotationComposer,
      $$LureVariantsTableCreateCompanionBuilder,
      $$LureVariantsTableUpdateCompanionBuilder,
      (LureVariantEntity, $$LureVariantsTableReferences),
      LureVariantEntity,
      PrefetchHooks Function({
        bool lureModelId,
        bool catchesRefs,
        bool tackleBoxEntriesRefs,
      })
    >;
typedef $$CatchesTableCreateCompanionBuilder =
    CatchesCompanion Function({
      required String id,
      required String fishingSpotId,
      required String species,
      required int caughtAt,
      Value<int?> weightGrams,
      Value<int?> lengthMillimeters,
      Value<String?> lureVariantId,
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
      Value<String?> lureVariantId,
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

  static $LureVariantsTable _lureVariantIdTable(_$AppDatabase db) => db
      .lureVariants
      .createAlias('catches__lure_variant_id__lure_variants__id');

  $$LureVariantsTableProcessedTableManager? get lureVariantId {
    final $_column = $_itemColumn<String>('lure_variant_id');
    if ($_column == null) return null;
    final manager = $$LureVariantsTableTableManager(
      $_db,
      $_db.lureVariants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lureVariantIdTable($_db));
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

  $$LureVariantsTableFilterComposer get lureVariantId {
    final $$LureVariantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableFilterComposer(
            $db: $db,
            $table: $db.lureVariants,
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

  $$LureVariantsTableOrderingComposer get lureVariantId {
    final $$LureVariantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableOrderingComposer(
            $db: $db,
            $table: $db.lureVariants,
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

  $$LureVariantsTableAnnotationComposer get lureVariantId {
    final $$LureVariantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableAnnotationComposer(
            $db: $db,
            $table: $db.lureVariants,
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
          PrefetchHooks Function({
            bool fishingSpotId,
            bool lureVariantId,
            bool catchPhotosRefs,
          })
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
                Value<String?> lureVariantId = const Value.absent(),
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
                lureVariantId: lureVariantId,
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
                Value<String?> lureVariantId = const Value.absent(),
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
                lureVariantId: lureVariantId,
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
              ({
                fishingSpotId = false,
                lureVariantId = false,
                catchPhotosRefs = false,
              }) {
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
                        if (lureVariantId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.lureVariantId,
                                    referencedTable: $$CatchesTableReferences
                                        ._lureVariantIdTable(db),
                                    referencedColumn: $$CatchesTableReferences
                                        ._lureVariantIdTable(db)
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
      PrefetchHooks Function({
        bool fishingSpotId,
        bool lureVariantId,
        bool catchPhotosRefs,
      })
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
typedef $$TackleBoxEntriesTableCreateCompanionBuilder =
    TackleBoxEntriesCompanion Function({
      required String id,
      required String lureVariantId,
      Value<String?> personalPhotoRelativePath,
      required int addedAt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TackleBoxEntriesTableUpdateCompanionBuilder =
    TackleBoxEntriesCompanion Function({
      Value<String> id,
      Value<String> lureVariantId,
      Value<String?> personalPhotoRelativePath,
      Value<int> addedAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$TackleBoxEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TackleBoxEntriesTable,
          TackleBoxEntryEntity
        > {
  $$TackleBoxEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LureVariantsTable _lureVariantIdTable(_$AppDatabase db) => db
      .lureVariants
      .createAlias('tackle_box_entries__lure_variant_id__lure_variants__id');

  $$LureVariantsTableProcessedTableManager get lureVariantId {
    final $_column = $_itemColumn<String>('lure_variant_id')!;

    final manager = $$LureVariantsTableTableManager(
      $_db,
      $_db.lureVariants,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lureVariantIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TackleBoxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $TackleBoxEntriesTable> {
  $$TackleBoxEntriesTableFilterComposer({
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

  ColumnFilters<String> get personalPhotoRelativePath => $composableBuilder(
    column: $table.personalPhotoRelativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
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

  $$LureVariantsTableFilterComposer get lureVariantId {
    final $$LureVariantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableFilterComposer(
            $db: $db,
            $table: $db.lureVariants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TackleBoxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TackleBoxEntriesTable> {
  $$TackleBoxEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get personalPhotoRelativePath => $composableBuilder(
    column: $table.personalPhotoRelativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
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

  $$LureVariantsTableOrderingComposer get lureVariantId {
    final $$LureVariantsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableOrderingComposer(
            $db: $db,
            $table: $db.lureVariants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TackleBoxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TackleBoxEntriesTable> {
  $$TackleBoxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personalPhotoRelativePath => $composableBuilder(
    column: $table.personalPhotoRelativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LureVariantsTableAnnotationComposer get lureVariantId {
    final $$LureVariantsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lureVariantId,
      referencedTable: $db.lureVariants,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LureVariantsTableAnnotationComposer(
            $db: $db,
            $table: $db.lureVariants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TackleBoxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TackleBoxEntriesTable,
          TackleBoxEntryEntity,
          $$TackleBoxEntriesTableFilterComposer,
          $$TackleBoxEntriesTableOrderingComposer,
          $$TackleBoxEntriesTableAnnotationComposer,
          $$TackleBoxEntriesTableCreateCompanionBuilder,
          $$TackleBoxEntriesTableUpdateCompanionBuilder,
          (TackleBoxEntryEntity, $$TackleBoxEntriesTableReferences),
          TackleBoxEntryEntity,
          PrefetchHooks Function({bool lureVariantId})
        > {
  $$TackleBoxEntriesTableTableManager(
    _$AppDatabase db,
    $TackleBoxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TackleBoxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TackleBoxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TackleBoxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lureVariantId = const Value.absent(),
                Value<String?> personalPhotoRelativePath = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TackleBoxEntriesCompanion(
                id: id,
                lureVariantId: lureVariantId,
                personalPhotoRelativePath: personalPhotoRelativePath,
                addedAt: addedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lureVariantId,
                Value<String?> personalPhotoRelativePath = const Value.absent(),
                required int addedAt,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TackleBoxEntriesCompanion.insert(
                id: id,
                lureVariantId: lureVariantId,
                personalPhotoRelativePath: personalPhotoRelativePath,
                addedAt: addedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TackleBoxEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lureVariantId = false}) {
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
                    if (lureVariantId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lureVariantId,
                                referencedTable:
                                    $$TackleBoxEntriesTableReferences
                                        ._lureVariantIdTable(db),
                                referencedColumn:
                                    $$TackleBoxEntriesTableReferences
                                        ._lureVariantIdTable(db)
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

typedef $$TackleBoxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TackleBoxEntriesTable,
      TackleBoxEntryEntity,
      $$TackleBoxEntriesTableFilterComposer,
      $$TackleBoxEntriesTableOrderingComposer,
      $$TackleBoxEntriesTableAnnotationComposer,
      $$TackleBoxEntriesTableCreateCompanionBuilder,
      $$TackleBoxEntriesTableUpdateCompanionBuilder,
      (TackleBoxEntryEntity, $$TackleBoxEntriesTableReferences),
      TackleBoxEntryEntity,
      PrefetchHooks Function({bool lureVariantId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FishingSpotsTableTableManager get fishingSpots =>
      $$FishingSpotsTableTableManager(_db, _db.fishingSpots);
  $$LureModelsTableTableManager get lureModels =>
      $$LureModelsTableTableManager(_db, _db.lureModels);
  $$LureVariantsTableTableManager get lureVariants =>
      $$LureVariantsTableTableManager(_db, _db.lureVariants);
  $$CatchesTableTableManager get catches =>
      $$CatchesTableTableManager(_db, _db.catches);
  $$CatchPhotosTableTableManager get catchPhotos =>
      $$CatchPhotosTableTableManager(_db, _db.catchPhotos);
  $$TackleBoxEntriesTableTableManager get tackleBoxEntries =>
      $$TackleBoxEntriesTableTableManager(_db, _db.tackleBoxEntries);
}
