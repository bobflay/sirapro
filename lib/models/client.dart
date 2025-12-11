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
}
