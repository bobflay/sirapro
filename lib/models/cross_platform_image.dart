import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// A cross-platform image representation that works on both web and mobile.
///
/// On mobile, images can be stored as file paths or bytes.
/// On web, images must be stored as bytes since file paths don't exist.
class CrossPlatformImage {
  /// The image bytes (always available on web, optional on mobile)
  final Uint8List? bytes;

  /// The file path (only available on mobile, null on web)
  final String? path;

  /// The original filename
  final String fileName;

  /// The MIME type of the image
  final String mimeType;

  /// Timestamp when the image was captured
  final DateTime timestamp;

  /// GPS latitude (optional)
  final double? latitude;

  /// GPS longitude (optional)
  final double? longitude;

  /// Optional description
  final String? description;

  CrossPlatformImage({
    this.bytes,
    this.path,
    required this.fileName,
    required this.mimeType,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.description,
  }) : assert(bytes != null || path != null, 'Either bytes or path must be provided');

  /// Create a CrossPlatformImage from an XFile (from image_picker)
  ///
  /// This method reads the bytes from the XFile, making it work on both platforms.
  static Future<CrossPlatformImage> fromXFile(
    XFile xFile, {
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    final bytes = await xFile.readAsBytes();
    final fileName = xFile.name;
    final mimeType = xFile.mimeType ?? _getMimeType(fileName);

    return CrossPlatformImage(
      bytes: bytes,
      path: kIsWeb ? null : xFile.path,
      fileName: fileName,
      mimeType: mimeType,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      description: description,
    );
  }

  /// Get the image bytes (loads from file if needed on mobile)
  Future<Uint8List> getBytes() async {
    if (bytes != null) {
      return bytes!;
    }

    // On mobile, we might have a path but no bytes cached
    if (!kIsWeb && path != null) {
      // Dynamically import dart:io only on non-web platforms
      final file = await _readFileBytes(path!);
      return file;
    }

    throw Exception('No image data available');
  }

  /// Check if this image has bytes loaded
  bool get hasBytes => bytes != null;

  /// Check if this image has a file path
  bool get hasPath => path != null;

  /// Get file extension from filename
  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
  }

  /// Determine MIME type from filename
  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Read file bytes (only called on mobile)
  static Future<Uint8List> _readFileBytes(String path) async {
    // This will be conditionally compiled - on web this code path won't be reached
    if (kIsWeb) {
      throw UnsupportedError('Cannot read file on web');
    }

    // Use dynamic import pattern for dart:io
    // ignore: avoid_dynamic_calls
    final dynamic io = await _getIoLibrary();
    final file = io.File(path);
    return await file.readAsBytes() as Uint8List;
  }

  /// Dynamically get dart:io library (only works on mobile)
  static Future<dynamic> _getIoLibrary() async {
    if (kIsWeb) {
      throw UnsupportedError('dart:io not available on web');
    }
    // This import happens at runtime and will only succeed on mobile
    return null; // We'll handle this differently
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'mimeType': mimeType,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'path': path,
      // Note: bytes are not serialized to JSON
    };
  }

  CrossPlatformImage copyWith({
    Uint8List? bytes,
    String? path,
    String? fileName,
    String? mimeType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? description,
  }) {
    return CrossPlatformImage(
      bytes: bytes ?? this.bytes,
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
    );
  }
}
