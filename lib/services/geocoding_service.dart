import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents address components extracted from reverse geocoding
class AddressComponents {
  final String? city;
  final String? quartier;
  final String? fullAddress;
  final String? country;

  AddressComponents({
    this.city,
    this.quartier,
    this.fullAddress,
    this.country,
  });

  @override
  String toString() {
    return 'AddressComponents(city: $city, quartier: $quartier, fullAddress: $fullAddress, country: $country)';
  }
}

/// Service for reverse geocoding GPS coordinates to address components
/// Uses Google Geocoding API directly for cross-platform support (including web)
class GeocodingService {
  // Using the same API key as Google Maps
  static const String _apiKey = 'AIzaSyBPCg0Ub9yH6crrhZfyY6OzJErbjmtrNxs';

  /// Reverse geocode coordinates to get address components
  /// Returns null if geocoding fails
  Future<AddressComponents?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$_apiKey'
        '&language=fr'
      );

      debugPrint('Geocoding request: $url');

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('Geocoding HTTP error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      debugPrint('Geocoding status: ${data['status']}');

      if (data['status'] != 'OK' || data['results'] == null || (data['results'] as List).isEmpty) {
        debugPrint('Geocoding failed: ${data['status']} - ${data['error_message'] ?? 'No results'}');
        return null;
      }

      final result = data['results'][0];
      final addressComponents = result['address_components'] as List;
      final formattedAddress = result['formatted_address'] as String?;

      // Debug: print all components
      debugPrint('=== Geocoding Result ===');
      debugPrint('Formatted address: $formattedAddress');
      for (var comp in addressComponents) {
        debugPrint('${comp['types']}: ${comp['long_name']}');
      }
      debugPrint('========================');

      // Extract components by type
      String? city;
      String? quartier;
      String? country;

      for (var component in addressComponents) {
        final types = List<String>.from(component['types']);
        final longName = component['long_name'] as String;

        // City: locality or administrative_area_level_2
        if (types.contains('locality')) {
          city = longName;
        } else if (city == null && types.contains('administrative_area_level_2')) {
          city = longName;
        }

        // Quartier: sublocality, neighborhood, or administrative_area_level_3
        if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
          quartier = longName;
        } else if (quartier == null && types.contains('neighborhood')) {
          quartier = longName;
        } else if (quartier == null && types.contains('administrative_area_level_3')) {
          quartier = longName;
        }

        // Country
        if (types.contains('country')) {
          country = longName;
        }
      }

      // Clean up city name
      if (city != null) {
        city = _cleanupCityName(city);
      }

      debugPrint('Extracted - City: $city, Quartier: $quartier, Country: $country');

      return AddressComponents(
        city: city,
        quartier: quartier,
        fullAddress: formattedAddress,
        country: country,
      );
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }

  /// Clean up city name by removing common prefixes
  String _cleanupCityName(String city) {
    // Remove "Commune de " prefix
    if (city.toLowerCase().startsWith('commune de ')) {
      return city.substring(11).trim();
    }
    // Remove "Commune d'" prefix
    if (city.toLowerCase().startsWith("commune d'")) {
      return city.substring(10).trim();
    }
    return city.trim();
  }
}
