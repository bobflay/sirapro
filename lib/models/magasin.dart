class Magasin {
  final int id;
  final String code;
  final String name;
  final String? city;
  final String? country;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;

  Magasin({
    required this.id,
    required this.code,
    required this.name,
    this.city,
    this.country,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
  });

  factory Magasin.fromJson(Map<String, dynamic> json) {
    return Magasin(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      city: json['city'] as String?,
      country: json['country'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'city': city,
      'country': country,
      'phone': phone,
      'email': email,
      'address': address,
      'is_active': isActive,
    };
  }
}
