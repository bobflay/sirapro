import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/visit_report.dart';

/// Service pour la capture de photos géolocalisées et horodatées
class PhotoCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// Vérifie et demande les permissions nécessaires
  Future<bool> checkAndRequestPermissions() async {
    // Permission caméra
    PermissionStatus cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }

    // Permission localisation
    PermissionStatus locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
    }

    return cameraStatus.isGranted && locationStatus.isGranted;
  }

  /// Vérifie si les services de localisation sont activés
  Future<bool> checkLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Obtient la position GPS actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Vérifier les permissions
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

      // Obtenir la position avec une haute précision
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
  Future<GeotaggedPhoto?> capturePhoto({
    String? description,
    bool fromCamera = true,
  }) async {
    try {
      // Vérifier les permissions
      bool hasPermissions = await checkAndRequestPermissions();
      if (!hasPermissions) {
        throw Exception('Permissions caméra ou localisation refusées');
      }

      // Capture de la photo
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) {
        return null;
      }

      // Obtenir la position GPS au moment de la capture
      Position? position = await getCurrentPosition();

      // Créer un nom de fichier unique avec timestamp
      final DateTime now = DateTime.now();
      final String timestamp = now.toIso8601String().replaceAll(':', '-');
      final String fileName = 'photo_$timestamp${path.extension(image.path)}';

      // Sauvegarder la photo dans le dossier de l'application
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String photosDir = path.join(appDir.path, 'photos');
      await Directory(photosDir).create(recursive: true);
      final String savedPath = path.join(photosDir, fileName);

      // Copier le fichier
      await File(image.path).copy(savedPath);

      // Créer l'objet GeotaggedPhoto
      return GeotaggedPhoto(
        path: savedPath,
        timestamp: now,
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
  Future<void> deletePhoto(String photoPath) async {
    try {
      final File file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Erreur lors de la suppression de la photo: $e');
    }
  }

  /// Obtient la taille d'une photo en Mo
  Future<double> getPhotoSizeMB(String photoPath) async {
    try {
      final File file = File(photoPath);
      if (await file.exists()) {
        final int bytes = await file.length();
        return bytes / (1024 * 1024);
      }
    } catch (e) {
      print('Erreur lors de la lecture de la taille de la photo: $e');
    }
    return 0;
  }

  /// Vérifie si une photo existe
  Future<bool> photoExists(String photoPath) async {
    try {
      return await File(photoPath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Nettoie les anciennes photos (plus de X jours)
  Future<void> cleanOldPhotos({int daysToKeep = 30}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String photosDir = path.join(appDir.path, 'photos');
      final Directory dir = Directory(photosDir);

      if (await dir.exists()) {
        final DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
        final List<FileSystemEntity> files = dir.listSync();

        for (var file in files) {
          if (file is File) {
            final FileStat stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      print('Erreur lors du nettoyage des anciennes photos: $e');
    }
  }
}
