import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/visit_report.dart';

// Conditional imports for mobile-only features
import 'photo_capture_service_mobile.dart'
    if (dart.library.html) 'photo_capture_service_web.dart' as platform;

/// Résultat de la vérification des permissions
class PermissionResult {
  final bool isGranted;
  final bool isPermanentlyDenied;
  final String message;
  final List<String> deniedPermissions;

  PermissionResult({
    required this.isGranted,
    this.isPermanentlyDenied = false,
    required this.message,
    this.deniedPermissions = const [],
  });
}

/// Service pour la capture de photos géolocalisées et horodatées
/// Works on both web and mobile platforms
class PhotoCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// Vérifie et demande les permissions nécessaires
  /// On web, permissions are handled by the browser automatically
  Future<PermissionResult> checkAndRequestPermissions() async {
    if (kIsWeb) {
      // On web, browser handles permissions automatically
      return PermissionResult(
        isGranted: true,
        message: 'Permissions handled by browser',
      );
    }

    // Mobile permission handling
    return platform.checkAndRequestPermissions();
  }

  /// Vérifie si les services de localisation sont activés
  Future<bool> checkLocationServiceEnabled() async {
    if (kIsWeb) {
      // On web, we'll try to get location and see if it works
      return true;
    }
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Obtient la position GPS actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      if (kIsWeb) {
        // On web, use Geolocator which has web support
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              return null;
            }
          }

          if (permission == LocationPermission.deniedForever) {
            return null;
          }

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          return position;
        } catch (e) {
          print('Web GPS error: $e');
          return null;
        }
      }

      // Mobile: Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('Erreur lors de l\'obtention de la position GPS: $e');
      return null;
    }
  }

  /// Capture une photo avec la caméra et ajoute GPS + timestamp
  /// Works on both web and mobile platforms
  Future<GeotaggedPhoto?> capturePhoto({
    String? description,
    bool fromCamera = true,
  }) async {
    try {
      // Check permissions (skipped on web)
      if (!kIsWeb) {
        PermissionResult permissionResult = await checkAndRequestPermissions();
        if (!permissionResult.isGranted) {
          throw Exception(permissionResult.message);
        }
      }

      // Capture the photo using image_picker (works on both platforms)
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) {
        return null;
      }

      // Get GPS position at capture time
      Position? position = await getCurrentPosition();

      // Create GeotaggedPhoto from XFile (works on both platforms)
      return await GeotaggedPhoto.fromXFile(
        image,
        latitude: position?.latitude,
        longitude: position?.longitude,
        description: description,
      );
    } catch (e) {
      print('Erreur lors de la capture de photo: $e');
      rethrow;
    }
  }

  /// Capture une photo avec la caméra
  Future<GeotaggedPhoto?> takePhoto({String? description}) async {
    return capturePhoto(description: description, fromCamera: true);
  }

  /// Sélectionne une photo depuis la galerie
  Future<GeotaggedPhoto?> pickFromGallery({String? description}) async {
    return capturePhoto(description: description, fromCamera: false);
  }

  /// Affiche un dialogue pour choisir entre caméra et galerie
  /// Retourne la source choisie ou null si annulé
  Future<ImageSource?> showImageSourceDialog() async {
    // Cette méthode sera appelée depuis l'UI avec un showDialog
    // Pour l'instant, on retourne juste caméra par défaut
    return ImageSource.camera;
  }

  /// Supprime une photo du stockage
  /// On web, this is a no-op since photos are stored in memory
  Future<void> deletePhoto(String photoPath) async {
    if (kIsWeb) {
      // On web, photos are in memory, nothing to delete from filesystem
      return;
    }

    try {
      await platform.deleteFile(photoPath);
    } catch (e) {
      print('Erreur lors de la suppression de la photo: $e');
    }
  }

  /// Obtient la taille d'une photo en Mo
  /// On web, returns 0 since we don't have filesystem access
  Future<double> getPhotoSizeMB(String photoPath) async {
    if (kIsWeb) {
      return 0;
    }

    try {
      return await platform.getFileSizeMB(photoPath);
    } catch (e) {
      print('Erreur lors de la lecture de la taille de la photo: $e');
      return 0;
    }
  }

  /// Vérifie si une photo existe
  /// On web, always returns false since we don't have filesystem access
  Future<bool> photoExists(String photoPath) async {
    if (kIsWeb) {
      return false;
    }

    try {
      return await platform.fileExists(photoPath);
    } catch (e) {
      return false;
    }
  }

  /// Nettoie les anciennes photos (plus de X jours)
  /// On web, this is a no-op since photos are stored in memory
  Future<void> cleanOldPhotos({int daysToKeep = 30}) async {
    if (kIsWeb) {
      // On web, photos are in memory, nothing to clean
      return;
    }

    try {
      await platform.cleanOldPhotos(daysToKeep: daysToKeep);
    } catch (e) {
      print('Erreur lors du nettoyage des anciennes photos: $e');
    }
  }
}
