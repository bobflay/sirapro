/// Stub file for dart:io types that aren't available on web.
/// This is only used for compilation - the actual code paths throw before using these types.

import 'dart:typed_data';

// ignore_for_file: avoid_unused_constructor_parameters

/// Stub File class for web compilation
class File {
  final String path;
  File(this.path);
  int lengthSync() => 0;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<File> writeAsBytes(List<int> bytes) async => this;
  bool existsSync() => false;
  void deleteSync() {}
  void createSync({bool recursive = false}) {}
}

/// Stub Directory class for web compilation
class Directory {
  final String path;
  Directory(this.path);
  bool existsSync() => false;
  void createSync({bool recursive = false}) {}
}
