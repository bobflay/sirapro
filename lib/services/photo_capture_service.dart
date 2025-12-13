import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/visit_report.dart';

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
class PhotoCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// Vérifie et demande les permissions nécessaires
  /// Retourne un PermissionResult avec le statut et les détails
  Future<PermissionResult> checkAndRequestPermissions() async {
    print('🔍 Vérification des permissions pour la caméra et la localisation...');

    // Vérifier d'abord l'état actuel avec permission_handler
    PermissionStatus cameraStatus = await Permission.camera.status;
    PermissionStatus locationStatus = await Permission.locationWhenInUse.status;

    print('📸 État caméra: $cameraStatus');
    print('📍 État localisation: $locationStatus');

    // Si les permissions sont déjà refusées de manière permanente
    bool cameraPermanentlyDenied = cameraStatus.isPermanentlyDenied;
    bool locationPermanentlyDenied = locationStatus.isPermanentlyDenied;

    if (cameraPermanentlyDenied || locationPermanentlyDenied) {
      List<String> deniedPermissions = [];
      if (cameraPermanentlyDenied) deniedPermissions.add('Caméra');
      if (locationPermanentlyDenied) deniedPermissions.add('Localisation');

      print('❌ Permissions refusées définitivement: ${deniedPermissions.join(", ")}');

      return PermissionResult(
        isGranted: false,
        isPermanentlyDenied: true,
        message: 'Les permissions ${deniedPermissions.join(" et ")} ont été refusées de manière permanente. Veuillez les activer dans les paramètres de l\'application.',
        deniedPermissions: deniedPermissions,
      );
    }

    // Si les permissions sont déjà accordées
    if (cameraStatus.isGranted && locationStatus.isGranted) {
      print('✅ Toutes les permissions sont déjà accordées');
      return PermissionResult(
        isGranted: true,
        message: 'Permissions accordées',
      );
    }

    // Pour iOS, on ne demande PAS les permissions ici avec permission_handler
    // car cela cause un bug où elles sont marquées comme permanentlyDenied
    // Les permissions seront demandées automatiquement par ImagePicker et Geolocator
    // quand on les utilise pour la première fois

    // Si les permissions ne sont pas encore accordées, on laisse passer
    // et on laisse ImagePicker/Geolocator les demander nativement
    print('⚠️ Permissions pas encore accordées - seront demandées par les plugins natifs');
    return PermissionResult(
      isGranted: true, // On dit que c'est OK, les plugins natifs vont demander
      message: 'Permissions seront demandées',
    );
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
      PermissionResult permissionResult = await checkAndRequestPermissions();
      if (!permissionResult.isGranted) {
        throw Exception(permissionResult.message);
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
