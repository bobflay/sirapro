/// Request model for creating a new client via POST /api/clients
class CreateClientRequest {
  /// Unique client code (required, max:255)
  final String code;

  /// Client name (required, max:255)
  final String name;

  /// Client type (required)
  /// One of: Boutique, Supermarché, Demi-grossiste, Grossiste, Distributeur, Autre
  final String type;

  /// Client type classification (optional)
  /// One of: B2B, B2C
  final String? clientType;

  /// Client potential (required)
  /// One of: A, B, C
  final String potential;

  /// Base commerciale ID (required, must exist in bases_commerciales table)
  final int baseCommercialeId;

  /// Zone ID (required, must exist in zones table)
  final int zoneId;

  /// Manager/Gérant name (optional, max:255)
  final String? managerName;

  /// Phone number (required, max:255)
  final String phone;

  /// WhatsApp number (optional, max:255)
  final String? whatsapp;

  /// Email address (optional, valid email, max:255)
  final String? email;

  /// City (required, max:255)
  final String city;

  /// District/Quartier (optional, max:255)
  final String? district;

  /// Address description (optional)
  final String? addressDescription;

  /// Latitude (required, between -90 and 90)
  final double latitude;

  /// Longitude (required, between -180 and 180)
  final double longitude;

  /// Visit frequency (required)
  /// One of: weekly, biweekly, monthly, other
  final String visitFrequency;

  /// Visit day (optional)
  /// One of: monday, tuesday, wednesday, thursday, friday, saturday, sunday
  final String? visitDay;

  /// Whether the client is active (optional, defaults to true)
  final bool? isActive;

  CreateClientRequest({
    required this.code,
    required this.name,
    required this.type,
    this.clientType,
    required this.potential,
    required this.baseCommercialeId,
    required this.zoneId,
    this.managerName,
    required this.phone,
    this.whatsapp,
    this.email,
    required this.city,
    this.district,
    this.addressDescription,
    required this.latitude,
    required this.longitude,
    required this.visitFrequency,
    this.visitDay,
    this.isActive,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'code': code,
      'name': name,
      'type': type,
      'potential': potential,
      'base_commerciale_id': baseCommercialeId,
      'zone_id': zoneId,
      'phone': phone,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'visit_frequency': visitFrequency,
    };

    // Add optional fields only if they have values
    if (clientType != null && clientType!.isNotEmpty) {
      json['client_type'] = clientType;
    }
    if (managerName != null && managerName!.isNotEmpty) {
      json['manager_name'] = managerName;
    }
    if (whatsapp != null && whatsapp!.isNotEmpty) {
      json['whatsapp'] = whatsapp;
    }
    if (email != null && email!.isNotEmpty) {
      json['email'] = email;
    }
    if (district != null && district!.isNotEmpty) {
      json['district'] = district;
    }
    if (addressDescription != null && addressDescription!.isNotEmpty) {
      json['address_description'] = addressDescription;
    }
    if (visitDay != null && visitDay!.isNotEmpty) {
      json['visit_day'] = visitDay;
    }
    if (isActive != null) {
      json['is_active'] = isActive;
    }

    return json;
  }

  /// Validate the request before sending
  /// Returns a list of validation errors, empty if valid
  List<String> validate() {
    final errors = <String>[];

    if (code.isEmpty) {
      errors.add('Le code client est requis');
    } else if (code.length > 255) {
      errors.add('Le code client ne peut pas dépasser 255 caractères');
    }

    if (name.isEmpty) {
      errors.add('Le nom du client est requis');
    } else if (name.length > 255) {
      errors.add('Le nom ne peut pas dépasser 255 caractères');
    }

    final validTypes = [
      'Boutique',
      'Supermarché',
      'Demi-grossiste',
      'Grossiste',
      'Distributeur',
      'Autre'
    ];
    if (!validTypes.contains(type)) {
      errors.add('Type de client invalide');
    }

    if (clientType != null && clientType!.isNotEmpty) {
      final validClientTypes = ['B2B', 'B2C'];
      if (!validClientTypes.contains(clientType)) {
        errors.add('Type de classification invalide (B2B ou B2C)');
      }
    }

    final validPotentials = ['A', 'B', 'C'];
    if (!validPotentials.contains(potential)) {
      errors.add('Potentiel invalide');
    }

    if (phone.isEmpty) {
      errors.add('Le numéro de téléphone est requis');
    } else if (phone.length > 255) {
      errors.add('Le numéro de téléphone ne peut pas dépasser 255 caractères');
    }

    if (city.isEmpty) {
      errors.add('La ville est requise');
    } else if (city.length > 255) {
      errors.add('La ville ne peut pas dépasser 255 caractères');
    }

    if (latitude < -90 || latitude > 90) {
      errors.add('Latitude invalide (doit être entre -90 et 90)');
    }

    if (longitude < -180 || longitude > 180) {
      errors.add('Longitude invalide (doit être entre -180 et 180)');
    }

    final validFrequencies = ['weekly', 'biweekly', 'monthly', 'other'];
    if (!validFrequencies.contains(visitFrequency)) {
      errors.add('Fréquence de visite invalide');
    }

    if (visitDay != null && visitDay!.isNotEmpty) {
      final validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      if (!validDays.contains(visitDay)) {
        errors.add('Jour de visite invalide');
      }
    }

    if (email != null && email!.isNotEmpty) {
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(email!)) {
        errors.add('Format d\'email invalide');
      }
    }

    return errors;
  }

  /// Map French frequency labels to API values
  static String frequencyToApiValue(String frenchLabel) {
    switch (frenchLabel) {
      case 'Hebdomadaire':
        return 'weekly';
      case 'Bimensuelle':
        return 'biweekly';
      case 'Mensuelle':
        return 'monthly';
      case 'Autre':
        return 'other';
      default:
        return 'other';
    }
  }

  /// Map API values to French frequency labels
  static String apiValueToFrequency(String apiValue) {
    switch (apiValue) {
      case 'weekly':
        return 'Hebdomadaire';
      case 'biweekly':
        return 'Bimensuelle';
      case 'monthly':
        return 'Mensuelle';
      case 'other':
        return 'Autre';
      default:
        return 'Autre';
    }
  }

  /// Map French day labels to API values
  static String? dayToApiValue(String? frenchLabel) {
    if (frenchLabel == null) return null;
    switch (frenchLabel) {
      case 'Lundi':
        return 'monday';
      case 'Mardi':
        return 'tuesday';
      case 'Mercredi':
        return 'wednesday';
      case 'Jeudi':
        return 'thursday';
      case 'Vendredi':
        return 'friday';
      case 'Samedi':
        return 'saturday';
      case 'Dimanche':
        return 'sunday';
      default:
        return null;
    }
  }

  /// Map API values to French day labels
  static String? apiValueToDay(String? apiValue) {
    if (apiValue == null) return null;
    switch (apiValue) {
      case 'monday':
        return 'Lundi';
      case 'tuesday':
        return 'Mardi';
      case 'wednesday':
        return 'Mercredi';
      case 'thursday':
        return 'Jeudi';
      case 'friday':
        return 'Vendredi';
      case 'saturday':
        return 'Samedi';
      case 'sunday':
        return 'Dimanche';
      default:
        return null;
    }
  }

  @override
  String toString() {
    return 'CreateClientRequest(code: $code, name: $name, type: $type)';
  }
}
