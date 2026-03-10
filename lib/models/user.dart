import 'magasin.dart';

class Role {
  final int id;
  final String code;
  final String name;
  final String? description;

  Role({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
    };
  }
}

class BaseCommerciale {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String? city;
  final String? region;
  final String? latitude;
  final String? longitude;
  final String? defaultCurrency;
  final String? defaultTaxRate;
  final bool allowDiscount;
  final String? maxDiscountPercent;
  final String? orderCutoffTime;
  final bool isActive;

  BaseCommerciale({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.city,
    this.region,
    this.latitude,
    this.longitude,
    this.defaultCurrency,
    this.defaultTaxRate,
    this.allowDiscount = true,
    this.maxDiscountPercent,
    this.orderCutoffTime,
    this.isActive = true,
  });

  factory BaseCommerciale.fromJson(Map<String, dynamic> json) {
    return BaseCommerciale(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      defaultCurrency: json['default_currency'] as String?,
      defaultTaxRate: json['default_tax_rate'] as String?,
      allowDiscount: json['allow_discount'] as bool? ?? true,
      maxDiscountPercent: json['max_discount_percent'] as String?,
      orderCutoffTime: json['order_cutoff_time'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'city': city,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
      'default_currency': defaultCurrency,
      'default_tax_rate': defaultTaxRate,
      'allow_discount': allowDiscount,
      'max_discount_percent': maxDiscountPercent,
      'order_cutoff_time': orderCutoffTime,
      'is_active': isActive,
    };
  }
}

class Zone {
  final int id;
  final String code;
  final String name;
  final int baseCommercialeId;
  final String? city;
  final String? latitude;
  final String? longitude;
  final bool isActive;

  Zone({
    required this.id,
    required this.code,
    required this.name,
    required this.baseCommercialeId,
    this.city,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      baseCommercialeId: json['base_commerciale_id'] as int,
      city: json['city'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'base_commerciale_id': baseCommercialeId,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? dob;
  final String? photo;
  final String? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Role> roles;
  final int? magasinId;
  final Magasin? magasin;
  final List<BaseCommerciale> basesCommerciales;
  final List<Zone> zones;
  final double balance;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.dob,
    this.photo,
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
    this.magasinId,
    this.magasin,
    this.roles = const [],
    this.basesCommerciales = const [],
    this.zones = const [],
    this.balance = 0.0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      dob: json['dob'] as String?,
      photo: json['photo'] as String?,
      emailVerifiedAt: json['email_verified_at'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      magasinId: json['magasin_id'] as int?,
      magasin: json['magasin'] != null
          ? Magasin.fromJson(json['magasin'] as Map<String, dynamic>)
          : null,
      roles: (json['roles'] as List<dynamic>?)
              ?.map((e) => Role.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      basesCommerciales: (json['bases_commerciales'] as List<dynamic>?)
              ?.map((e) => BaseCommerciale.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      zones: (json['zones'] as List<dynamic>?)
              ?.map((e) => Zone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'dob': dob,
      'photo': photo,
      'email_verified_at': emailVerifiedAt,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'magasin_id': magasinId,
      'magasin': magasin?.toJson(),
      'roles': roles.map((e) => e.toJson()).toList(),
      'bases_commerciales': basesCommerciales.map((e) => e.toJson()).toList(),
      'zones': zones.map((e) => e.toJson()).toList(),
      'balance': balance,
    };
  }

  /// Check if user has a specific role by code
  bool hasRole(String roleCode) {
    return roles.any((role) => role.code == roleCode);
  }

  /// Check if user is a super admin
  bool get isSuperAdmin => hasRole('ROLE_SUPER_ADMIN');

  /// Get primary role name
  String? get primaryRoleName => roles.isNotEmpty ? roles.first.name : null;

  /// Get primary base commerciale
  BaseCommerciale? get primaryBase =>
      basesCommerciales.isNotEmpty ? basesCommerciales.first : null;

  /// Get primary zone
  Zone? get primaryZone => zones.isNotEmpty ? zones.first : null;

  /// Get magasin name
  String? get magasinName => magasin?.name;

  /// Base URL for API
  static const String _baseUrl = 'https://sira.xpertbot.online';

  /// Get the full photo URL
  /// Returns null if no valid photo is available
  String? get photoUrl {
    if (photo == null || photo!.isEmpty) {
      return null;
    }

    // If photo already has the full URL, return it
    if (photo!.startsWith('http://') || photo!.startsWith('https://')) {
      // Check if it's just the base storage URL without an actual file
      if (photo!.endsWith('/storage/') || photo!.endsWith('/storage')) {
        return null;
      }
      return photo;
    }

    // Otherwise, construct the full URL
    final path = photo!.startsWith('/') ? photo! : '/$photo';
    return '$_baseUrl$path';
  }

  /// Check if user has a valid photo
  bool get hasValidPhoto => photoUrl != null;
}
