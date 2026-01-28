/// Model representing a notification from the API response
/// Used for GET /api/notifications response
class ApiNotification {
  final int id;
  final String title;
  final String message;
  final int userId;
  final DateTime? seen;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  ApiNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.userId,
    this.seen,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory ApiNotification.fromJson(Map<String, dynamic> json) {
    return ApiNotification(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      userId: _parseInt(json['user_id']) ?? 0,
      seen: _parseDateTime(json['seen']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      deletedAt: _parseDateTime(json['deleted_at']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'user_id': userId,
      'seen': seen?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  /// Check if the notification has been read
  bool get isRead => seen != null;

  /// Check if the notification is unread
  bool get isUnread => seen == null;
}
