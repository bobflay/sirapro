// Stub for dart:html on non-web platforms
// This file provides empty implementations to satisfy the type system
// The actual web-specific code is guarded by kIsWeb checks

class Blob {
  Blob(List<dynamic> parts, String type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}
