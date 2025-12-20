class ClientPhoto {
  final int id;
  final String url;
  final String fileName;
  final String? type;
  final String? title;
  final String? description;
  final DateTime? takenAt;

  ClientPhoto({
    required this.id,
    required this.url,
    required this.fileName,
    this.type,
    this.title,
    this.description,
    this.takenAt,
  });

  /// Get the full URL for the photo
  String getFullUrl(String baseUrl) {
    if (url.startsWith('http')) {
      return url;
    }
    return '$baseUrl$url';
  }

  factory ClientPhoto.fromJson(Map<String, dynamic> json) {
    return ClientPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      fileName: json['file_name'] as String,
      type: json['type'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      takenAt: json['taken_at'] != null
          ? DateTime.parse(json['taken_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'file_name': fileName,
      'type': type,
      'title': title,
      'description': description,
      'taken_at': takenAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ClientPhoto(id: $id, url: $url, type: $type)';
  }
}
