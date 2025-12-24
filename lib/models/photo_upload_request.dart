import 'package:flutter/foundation.dart' show kIsWeb;

/// Request model for uploading client photos via POST /api/clients/{client_id}/photos
class PhotoUploadRequest {
  /// List of photo files to upload (required, 1-10 files)
  /// On mobile: List<File>, on web: not used (use uploadGeotaggedPhotos instead)
  final List<dynamic> photos;

  /// Photo type (optional)
  /// One of: facade, shelves, stock, anomaly, other
  final String? type;

  /// Photo title (optional, max:255)
  final String? title;

  /// Photo description (optional)
  final String? description;

  /// GPS latitude where photo was taken (optional, -90 to 90)
  final double? latitude;

  /// GPS longitude where photo was taken (optional, -180 to 180)
  final double? longitude;

  PhotoUploadRequest({
    required this.photos,
    this.type,
    this.title,
    this.description,
    this.latitude,
    this.longitude,
  });

  /// Get additional form fields for the multipart request
  Map<String, String> toFields() {
    final fields = <String, String>{};

    if (type != null && type!.isNotEmpty) {
      fields['type'] = type!;
    }
    if (title != null && title!.isNotEmpty) {
      fields['title'] = title!;
    }
    if (description != null && description!.isNotEmpty) {
      fields['description'] = description!;
    }
    if (latitude != null) {
      fields['latitude'] = latitude!.toString();
    }
    if (longitude != null) {
      fields['longitude'] = longitude!.toString();
    }

    return fields;
  }

  /// Validate the request before sending
  /// Returns a list of validation errors, empty if valid
  List<String> validate() {
    final errors = <String>[];

    if (photos.isEmpty) {
      errors.add('Au moins une photo est requise');
    } else if (photos.length > 10) {
      errors.add('Maximum 10 photos par requête');
    }

    // File-specific validations (only on mobile)
    // Uses dynamic typing to avoid dart:io import which doesn't exist on web
    if (!kIsWeb) {
      // Check file sizes (10MB max per image)
      const maxFileSize = 10 * 1024 * 1024; // 10MB in bytes
      for (int i = 0; i < photos.length; i++) {
        final dynamic file = photos[i];
        if ((file.lengthSync() as int) > maxFileSize) {
          errors.add('Photo ${i + 1} dépasse la taille maximale de 10MB');
        }
      }

      // Validate file extensions
      final validExtensions = ['jpeg', 'jpg', 'png'];
      for (int i = 0; i < photos.length; i++) {
        final dynamic file = photos[i];
        final extension = (file.path as String).split('.').last.toLowerCase();
        if (!validExtensions.contains(extension)) {
          errors.add('Photo ${i + 1}: format invalide (seuls jpeg, jpg, png sont acceptés)');
        }
      }
    }

    // Validate type if provided
    if (type != null && type!.isNotEmpty) {
      final validTypes = ['facade', 'shelves', 'stock', 'anomaly', 'other'];
      if (!validTypes.contains(type)) {
        errors.add('Type de photo invalide');
      }
    }

    // Validate GPS coordinates if provided
    if (latitude != null) {
      if (latitude! < -90 || latitude! > 90) {
        errors.add('Latitude invalide');
      }
    }
    if (longitude != null) {
      if (longitude! < -180 || longitude! > 180) {
        errors.add('Longitude invalide');
      }
    }

    return errors;
  }

  /// Map French photo type labels to API values
  static String typeToApiValue(String frenchLabel) {
    switch (frenchLabel.toLowerCase()) {
      case 'façade':
      case 'facade':
        return 'facade';
      case 'rayons':
      case 'shelves':
        return 'shelves';
      case 'stock':
        return 'stock';
      case 'anomalie':
      case 'anomaly':
        return 'anomaly';
      case 'autre':
      case 'other':
      default:
        return 'other';
    }
  }

  /// Map API values to French photo type labels
  static String apiValueToType(String apiValue) {
    switch (apiValue) {
      case 'facade':
        return 'Façade';
      case 'shelves':
        return 'Rayons';
      case 'stock':
        return 'Stock';
      case 'anomaly':
        return 'Anomalie';
      case 'other':
      default:
        return 'Autre';
    }
  }

  @override
  String toString() {
    return 'PhotoUploadRequest(photos: ${photos.length}, type: $type)';
  }
}

/// Response model for uploaded photos
class PhotoUploadResult {
  final int id;
  final String url;
  final String fileName;
  final String? type;

  PhotoUploadResult({
    required this.id,
    required this.url,
    required this.fileName,
    this.type,
  });

  factory PhotoUploadResult.fromJson(Map<String, dynamic> json) {
    return PhotoUploadResult(
      id: json['id'] as int,
      url: json['url'] as String,
      fileName: json['file_name'] as String,
      type: json['type'] as String?,
    );
  }

  /// Get full URL for the photo
  String getFullUrl(String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    return '$baseUrl$url';
  }

  @override
  String toString() {
    return 'PhotoUploadResult(id: $id, url: $url, type: $type)';
  }
}

/// Response wrapper for photo upload API
class PhotoUploadResponse {
  final bool status;
  final String message;
  final List<PhotoUploadResult> photos;

  PhotoUploadResponse({
    required this.status,
    required this.message,
    required this.photos,
  });

  factory PhotoUploadResponse.fromJson(Map<String, dynamic> json) {
    return PhotoUploadResponse(
      status: json['status'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      photos: (json['data'] as List<dynamic>?)
              ?.map((e) => PhotoUploadResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() {
    return 'PhotoUploadResponse(status: $status, photos: ${photos.length})';
  }
}
