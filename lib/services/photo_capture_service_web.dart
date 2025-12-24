import 'photo_capture_service.dart';

/// Web-specific implementation for photo capture service
/// On web, most file operations are no-ops since we work with bytes in memory

/// Check and request permissions on web
/// On web, browser handles permissions automatically
Future<PermissionResult> checkAndRequestPermissions() async {
  return PermissionResult(
    isGranted: true,
    message: 'Permissions handled by browser',
  );
}

/// Delete a file on web - no-op
Future<void> deleteFile(String path) async {
  // On web, photos are in memory, nothing to delete
}

/// Get file size in MB on web - returns 0
Future<double> getFileSizeMB(String path) async {
  return 0;
}

/// Check if file exists on web - always returns false
Future<bool> fileExists(String path) async {
  return false;
}

/// Clean old photos on web - no-op
Future<void> cleanOldPhotos({int daysToKeep = 30}) async {
  // On web, photos are in memory, nothing to clean
}
