/// Request model for updating an existing client via PUT /api/clients/{id}
/// All fields are optional for partial updates
class UpdateClientRequest {
  /// Unique client code (optional, max:255)
  final String? code;

  /// Client name (optional, max:255)
  final String? name;

  /// Client type (optional)
  /// One of: Boutique, Supermarché, Demi-grossiste, Grossiste, Distributeur, Mamie marché, Étalage, Boulangerie, Autre
  final String? type;

  /// Client potential (optional)
  /// One of: A, B, C
  final String? potential;

  /// Base commerciale ID (optional, must exist in bases_commerciales table)
  final int? baseCommercialeId;

  /// Zone ID (optional, must exist in zones table)
  final int? zoneId;

  /// Manager/Gérant name (optional, max:255, nullable)
  final String? managerName;

  /// Phone number (optional, max:255)
  final String? phone;

  /// WhatsApp number (optional, max:255, nullable)
  final String? whatsapp;

  /// Email address (optional, valid email, max:255, nullable)
  final String? email;

  /// City (optional, max:255)
  final String? city;

  /// District/Quartier (optional, max:255, nullable)
  final String? district;

  /// Address description (optional, nullable)
  final String? addressDescription;

  /// Latitude (optional, between -90 and 90)
  final double? latitude;

  /// Longitude (optional, between -180 and 180)
  final double? longitude;

  /// Visit frequency (optional)
  /// One of: weekly, biweekly, monthly, other
  final String? visitFrequency;

  /// Whether the client is active (optional, nullable)
  final bool? isActive;

  UpdateClientRequest({
    this.code,
    this.name,
    this.type,
    this.potential,
    this.baseCommercialeId,
    this.zoneId,
    this.managerName,
    this.phone,
    this.whatsapp,
    this.email,
    this.city,
    this.district,
    this.addressDescription,
    this.latitude,
    this.longitude,
    this.visitFrequency,
    this.isActive,
  });

  /// Convert to JSON for API request
  /// Only includes fields that have been set (non-null)
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (code != null) {
      json['code'] = code;
    }
    if (name != null) {
      json['name'] = name;
    }
    if (type != null) {
      json['type'] = type;
    }
    if (potential != null) {
      json['potential'] = potential;
    }
    if (baseCommercialeId != null) {
      json['base_commerciale_id'] = baseCommercialeId;
    }
    if (zoneId != null) {
      json['zone_id'] = zoneId;
    }
    if (managerName != null) {
      json['manager_name'] = managerName;
    }
    if (phone != null) {
      json['phone'] = phone;
    }
    if (whatsapp != null) {
      json['whatsapp'] = whatsapp;
    }
    if (email != null) {
      json['email'] = email;
    }
    if (city != null) {
      json['city'] = city;
    }
    if (district != null) {
      json['district'] = district;
    }
    if (addressDescription != null) {
      json['address_description'] = addressDescription;
    }
    if (latitude != null) {
      json['latitude'] = latitude;
    }
    if (longitude != null) {
      json['longitude'] = longitude;
    }
    if (visitFrequency != null) {
      json['visit_frequency'] = visitFrequency;
    }
    if (isActive != null) {
      json['is_active'] = isActive;
    }

    return json;
  }

  /// Check if any fields are set for update
  bool get hasChanges => toJson().isNotEmpty;

  /// Validate the request before sending
  /// Returns a list of validation errors, empty if valid
  List<String> validate() {
    final errors = <String>[];

    if (code != null) {
      if (code!.isEmpty) {
        errors.add('Le code client ne peut pas être vide');
      } else if (code!.length > 255) {
        errors.add('Le code client ne peut pas dépasser 255 caractères');
      }
    }

    if (name != null) {
      if (name!.isEmpty) {
        errors.add('Le nom du client ne peut pas être vide');
      } else if (name!.length > 255) {
        errors.add('Le nom ne peut pas dépasser 255 caractères');
      }
    }

    if (type != null) {
      final validTypes = [
        'Boutique',
        'Supermarché',
        'Demi-grossiste',
        'Grossiste',
        'Distributeur',
        'Mamie marché',
        'Étalage',
        'Boulangerie',
        'Autre'
      ];
      if (!validTypes.contains(type)) {
        errors.add('Type de client invalide');
      }
    }

    if (potential != null) {
      final validPotentials = ['A', 'B', 'C'];
      if (!validPotentials.contains(potential)) {
        errors.add('Potentiel invalide');
      }
    }

    if (phone != null) {
      if (phone!.isEmpty) {
        errors.add('Le numéro de téléphone ne peut pas être vide');
      } else if (phone!.length > 255) {
        errors.add('Le numéro de téléphone ne peut pas dépasser 255 caractères');
      }
    }

    if (city != null) {
      if (city!.isEmpty) {
        errors.add('La ville ne peut pas être vide');
      } else if (city!.length > 255) {
        errors.add('La ville ne peut pas dépasser 255 caractères');
      }
    }

    if (latitude != null) {
      if (latitude! < -90 || latitude! > 90) {
        errors.add('Latitude invalide (doit être entre -90 et 90)');
      }
    }

    if (longitude != null) {
      if (longitude! < -180 || longitude! > 180) {
        errors.add('Longitude invalide (doit être entre -180 et 180)');
      }
    }

    if (visitFrequency != null) {
      final validFrequencies = ['weekly', 'biweekly', 'monthly', 'other'];
      if (!validFrequencies.contains(visitFrequency)) {
        errors.add('Fréquence de visite invalide');
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

  @override
  String toString() {
    return 'UpdateClientRequest(${toJson()})';
  }
}
