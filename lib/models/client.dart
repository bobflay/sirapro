import 'client_photo.dart';

class Client {
  final int id;
  final String name;
  final String type;
  final String? clientType;
  final String managerName;
  final List<String> phones;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;
  final int? magasinId;
  final String? magasinName;
  final int? zoneId;
  final int? commercialId;
  final String? potential;
  final String? visitFrequency;
  final String? visitDay;
  final DateTime? lastVisitDate;
  final bool hasOpenAlert;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Photos from API
  final List<ClientPhoto> photos;

  // Legacy fields for backward compatibility with existing UI
  final String? whatsapp;
  final String? email;
  final String? quartier;
  final String? zone;
  final String? gpsLocation;
  final String? status;
  final bool? isActive;

  Client({
    required this.id,
    required this.name,
    required this.type,
    this.clientType,
    required this.managerName,
    required this.phones,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
    this.magasinId,
    this.magasinName,
    this.zoneId,
    this.commercialId,
    this.potential,
    this.visitFrequency,
    this.visitDay,
    this.lastVisitDate,
    required this.hasOpenAlert,
    required this.createdAt,
    required this.updatedAt,
    this.photos = const [],
    // Legacy fields
    this.whatsapp,
    this.email,
    this.quartier,
    this.zone,
    this.gpsLocation,
    this.status,
    this.isActive,
  });

  // Legacy constructor for backward compatibility with existing UI code
  factory Client.legacy({
    required String id,
    required String boutiqueName,
    required String type,
    required String gerantName,
    required String phone,
    String? whatsapp,
    String? email,
    required String address,
    required String quartier,
    required String ville,
    String? zone,
    String? gpsLocation,
    String? potentiel,
    String? frequenceVisite,
    required String status,
    required bool isActive,
    required DateTime createdAt,
  }) {
    // Parse GPS location to latitude/longitude
    double? lat;
    double? lng;
    if (gpsLocation != null) {
      final coords = gpsLocation
          .replaceAll('°', '')
          .replaceAll(' N', '')
          .replaceAll(' S', '')
          .replaceAll(' E', '')
          .replaceAll(' W', '')
          .split(',');
      if (coords.length >= 2) {
        lat = double.tryParse(coords[0].trim());
        lng = double.tryParse(coords[1].trim());
      }
    }

    return Client(
      id: int.tryParse(id) ?? id.hashCode,
      name: boutiqueName,
      type: type,
      managerName: gerantName,
      phones: [phone],
      city: ville,
      address: address,
      latitude: lat,
      longitude: lng,
      potential: potentiel,
      visitFrequency: frequenceVisite,
      hasOpenAlert: false,
      createdAt: createdAt,
      updatedAt: createdAt,
      // Store legacy fields
      whatsapp: whatsapp,
      email: email,
      quartier: quartier,
      zone: zone,
      gpsLocation: gpsLocation,
      status: status,
      isActive: isActive,
    );
  }

  // Legacy getters for backward compatibility
  String get boutiqueName => name;
  String get gerantName => managerName;
  String get phone => phones.isNotEmpty ? phones.first : '';
  String get ville => city;
  String? get potentiel => potential;
  String? get frequenceVisite => visitFrequency;

  /// Display name for the client
  String get displayName => name;

  /// Primary phone number
  String? get primaryPhone => phones.isNotEmpty ? phones.first : null;

  /// Full address combining address and city
  String get fullAddress {
    if (quartier != null && quartier!.isNotEmpty) {
      return '$address, $quartier, $city';
    }
    return '$address, $city';
  }

  /// Check if client has GPS coordinates
  bool get hasLocation => latitude != null && longitude != null;

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      clientType: json['client_type'] as String?,
      managerName: json['manager_name'] as String,
      phones: (json['phones'] as List<dynamic>).map((e) => e as String).toList(),
      city: json['city'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      magasinId: json['magasin_id'] as int?,
      magasinName: json['magasin_name'] as String?,
      zoneId: json['zone_id'] as int?,
      commercialId: json['commercial_id'] as int?,
      potential: json['potential'] as String?,
      visitFrequency: json['visit_frequency'] as String?,
      visitDay: json['visit_day'] as String?,
      lastVisitDate: json['last_visit_date'] != null
          ? DateTime.parse(json['last_visit_date'] as String)
          : null,
      hasOpenAlert: json['has_open_alert'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Photos from API
      photos: json['photos'] != null
          ? (json['photos'] as List<dynamic>)
              .map((e) => ClientPhoto.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      // Legacy fields from API
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      quartier: json['district'] as String?,
      zone: json['zone'] as String?,
      gpsLocation: json['gps_location'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'client_type': clientType,
      'manager_name': managerName,
      'phones': phones,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'magasin_id': magasinId,
      'magasin_name': magasinName,
      'zone_id': zoneId,
      'commercial_id': commercialId,
      'potential': potential,
      'visit_frequency': visitFrequency,
      'visit_day': visitDay,
      'last_visit_date': lastVisitDate?.toIso8601String().split('T').first,
      'has_open_alert': hasOpenAlert,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Client copyWith({
    int? id,
    String? name,
    String? type,
    String? clientType,
    String? managerName,
    List<String>? phones,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    int? magasinId,
    String? magasinName,
    int? zoneId,
    int? commercialId,
    String? potential,
    String? visitFrequency,
    String? visitDay,
    DateTime? lastVisitDate,
    bool? hasOpenAlert,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ClientPhoto>? photos,
    // Legacy fields
    String? whatsapp,
    String? email,
    String? quartier,
    String? zone,
    String? gpsLocation,
    String? status,
    bool? isActive,
    // Legacy field name aliases
    String? boutiqueName,
    String? gerantName,
    String? phone,
    String? ville,
    String? potentiel,
    String? frequenceVisite,
  }) {
    // Handle phones update from legacy phone field
    List<String> updatedPhones = phones ?? this.phones;
    if (phone != null && phones == null) {
      updatedPhones = [phone];
    }

    return Client(
      id: id ?? this.id,
      name: boutiqueName ?? name ?? this.name,
      type: type ?? this.type,
      clientType: clientType ?? this.clientType,
      managerName: gerantName ?? managerName ?? this.managerName,
      phones: updatedPhones,
      city: ville ?? city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      magasinId: magasinId ?? this.magasinId,
      magasinName: magasinName ?? this.magasinName,
      zoneId: zoneId ?? this.zoneId,
      commercialId: commercialId ?? this.commercialId,
      potential: potentiel ?? potential ?? this.potential,
      visitFrequency: frequenceVisite ?? visitFrequency ?? this.visitFrequency,
      visitDay: visitDay ?? this.visitDay,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      hasOpenAlert: hasOpenAlert ?? this.hasOpenAlert,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photos: photos ?? this.photos,
      // Legacy fields
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      quartier: quartier ?? this.quartier,
      zone: zone ?? this.zone,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, type: $type, city: $city)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
