class Client {
  final String id;
  final String boutiqueName;
  final String type;
  final String gerantName;
  final String phone;
  final String? whatsapp;
  final String? email;
  final String address;
  final String quartier;
  final String ville;
  final String? zone;
  final String? gpsLocation;
  final String? potentiel;
  final String? frequenceVisite;
  final String status;
  final bool isActive;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.boutiqueName,
    required this.type,
    required this.gerantName,
    required this.phone,
    this.whatsapp,
    this.email,
    required this.address,
    required this.quartier,
    required this.ville,
    this.zone,
    this.gpsLocation,
    this.potentiel,
    this.frequenceVisite,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  // Display name for the client card (boutique name)
  String get displayName => boutiqueName;

  // Full address combining quartier and ville
  String get fullAddress => '$address, $quartier, $ville';

  // Create a copy with updated fields
  Client copyWith({
    String? id,
    String? boutiqueName,
    String? type,
    String? gerantName,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? quartier,
    String? ville,
    String? zone,
    String? gpsLocation,
    String? potentiel,
    String? frequenceVisite,
    String? status,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      boutiqueName: boutiqueName ?? this.boutiqueName,
      type: type ?? this.type,
      gerantName: gerantName ?? this.gerantName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      quartier: quartier ?? this.quartier,
      ville: ville ?? this.ville,
      zone: zone ?? this.zone,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      potentiel: potentiel ?? this.potentiel,
      frequenceVisite: frequenceVisite ?? this.frequenceVisite,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
