import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'photo_capture_service.dart';

/// Mobile-specific implementation for photo capture service

/// Check and request permissions on mobile
Future<PermissionResult> checkAndRequestPermissions() async {
  print('🔍 Vérification des permissions pour la caméra et la localisation...');

  // Check current permission status
  PermissionStatus cameraStatus = await Permission.camera.status;
  PermissionStatus locationStatus = await Permission.locationWhenInUse.status;

  print('📸 État caméra: $cameraStatus');
  print('📍 État localisation: $locationStatus');

  // If permissions are permanently denied
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
      message:
          'Les permissions ${deniedPermissions.join(" et ")} ont été refusées de manière permanente. Veuillez les activer dans les paramètres de l\'application.',
      deniedPermissions: deniedPermissions,
    );
  }

  // If permissions are already granted
  if (cameraStatus.isGranted && locationStatus.isGranted) {
    print('✅ Toutes les permissions sont déjà accordées');
    return PermissionResult(
      isGranted: true,
      message: 'Permissions accordées',
    );
  }

  // For iOS, we don't request permissions here with permission_handler
  // because it causes a bug where they are marked as permanentlyDenied
  // Permissions will be requested automatically by ImagePicker and Geolocator
  // when they are used for the first time

  print('⚠️ Permissions pas encore accordées - seront demandées par les plugins natifs');
  return PermissionResult(
    isGranted: true, // We say it's OK, native plugins will ask
    message: 'Permissions seront demandées',
  );
}

/// Delete a file on mobile
Future<void> deleteFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

/// Get file size in MB on mobile
Future<double> getFileSizeMB(String path) async {
  final file = File(path);
  if (await file.exists()) {
    final int bytes = await file.length();
    return bytes / (1024 * 1024);
  }
  return 0;
}

/// Check if file exists on mobile
Future<bool> fileExists(String path) async {
  return await File(path).exists();
}

/// Clean old photos on mobile
Future<void> cleanOldPhotos({int daysToKeep = 30}) async {
  final Directory appDir = await getApplicationDocumentsDirectory();
  final String photosDir = '${appDir.path}/photos';
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
}
