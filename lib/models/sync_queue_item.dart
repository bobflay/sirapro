import 'dart:convert';

/// Operation types for sync queue
enum SyncOperation {
  create,
  update,
  delete;

  String get value {
    switch (this) {
      case SyncOperation.create:
        return 'create';
      case SyncOperation.update:
        return 'update';
      case SyncOperation.delete:
        return 'delete';
    }
  }

  static SyncOperation fromString(String value) {
    switch (value) {
      case 'create':
        return SyncOperation.create;
      case 'update':
        return SyncOperation.update;
      case 'delete':
        return SyncOperation.delete;
      default:
        return SyncOperation.create;
    }
  }
}

/// Entity types that can be synced
enum SyncEntityType {
  client,
  order,
  visit,
  visitReport,
  alert;

  String get value {
    switch (this) {
      case SyncEntityType.client:
        return 'client';
      case SyncEntityType.order:
        return 'order';
      case SyncEntityType.visit:
        return 'visit';
      case SyncEntityType.visitReport:
        return 'visit_report';
      case SyncEntityType.alert:
        return 'alert';
    }
  }

  String get displayName {
    switch (this) {
      case SyncEntityType.client:
        return 'Client';
      case SyncEntityType.order:
        return 'Commande';
      case SyncEntityType.visit:
        return 'Visite';
      case SyncEntityType.visitReport:
        return 'Rapport de visite';
      case SyncEntityType.alert:
        return 'Alerte';
    }
  }

  static SyncEntityType fromString(String value) {
    switch (value) {
      case 'client':
        return SyncEntityType.client;
      case 'order':
        return SyncEntityType.order;
      case 'visit':
        return SyncEntityType.visit;
      case 'visit_report':
        return SyncEntityType.visitReport;
      case 'alert':
        return SyncEntityType.alert;
      default:
        return SyncEntityType.client;
    }
  }
}

/// Represents an item in the sync queue
class SyncQueueItem {
  final int? id;
  final SyncEntityType entityType;
  final int? entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  SyncQueueItem({
    this.id,
    required this.entityType,
    this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Create from database row
  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      entityType: SyncEntityType.fromString(map['entity_type'] as String),
      entityId: map['entity_id'] as int?,
      operation: SyncOperation.fromString(map['operation'] as String),
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType.value,
      'entity_id': entityId,
      'operation': operation.value,
      'payload': jsonEncode(payload),
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  /// Create a copy with updated retry info
  SyncQueueItem copyWithRetry({String? error}) {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      lastError: error,
    );
  }

  /// Get description for display
  String get description {
    final opName = operation == SyncOperation.create
        ? 'Créer'
        : operation == SyncOperation.update
            ? 'Mettre à jour'
            : 'Supprimer';
    return '$opName ${entityType.displayName}';
  }

  /// Check if max retries exceeded (max 3 retries)
  bool get hasExceededMaxRetries => retryCount >= 3;

  @override
  String toString() {
    return 'SyncQueueItem(id: $id, type: ${entityType.value}, op: ${operation.value}, retries: $retryCount)';
  }
}

/// Sync status for each entity type
class SyncStatus {
  final String entityType;
  final DateTime? lastSyncAt;
  final int itemCount;
  final bool isSyncing;
  final String? error;

  SyncStatus({
    required this.entityType,
    this.lastSyncAt,
    this.itemCount = 0,
    this.isSyncing = false,
    this.error,
  });

  factory SyncStatus.fromMap(Map<String, dynamic> map) {
    return SyncStatus(
      entityType: map['entity_type'] as String,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
      itemCount: map['item_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entity_type': entityType,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'item_count': itemCount,
    };
  }

  SyncStatus copyWith({
    DateTime? lastSyncAt,
    int? itemCount,
    bool? isSyncing,
    String? error,
  }) {
    return SyncStatus(
      entityType: entityType,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      itemCount: itemCount ?? this.itemCount,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }
}
