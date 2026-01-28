import 'dart:async';
import '../../models/sync_queue_item.dart';
import '../api_service.dart';
import 'database_service.dart';
import 'connectivity_service.dart';

/// Service for managing the sync queue of pending operations
class SyncQueueService {
  static SyncQueueService? _instance;
  final DatabaseService _database;
  final ConnectivityService _connectivity;
  final ApiService _apiService;

  bool _isProcessing = false;
  final StreamController<int> _pendingCountController = StreamController<int>.broadcast();

  SyncQueueService._internal(this._database, this._connectivity, this._apiService);

  factory SyncQueueService({
    DatabaseService? database,
    ConnectivityService? connectivity,
    ApiService? apiService,
  }) {
    _instance ??= SyncQueueService._internal(
      database ?? DatabaseService(),
      connectivity ?? ConnectivityService(),
      apiService ?? ApiService(),
    );
    return _instance!;
  }

  /// Stream of pending item counts
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Check if currently processing queue
  bool get isProcessing => _isProcessing;

  /// Add an item to the sync queue
  Future<void> enqueue({
    required SyncEntityType entityType,
    int? entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final item = SyncQueueItem(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await _database.addToSyncQueue(item);
    _notifyPendingCount();
  }

  /// Get count of pending items
  Future<int> getPendingCount() async {
    return await _database.getPendingSyncCount();
  }

  /// Get all pending items
  Future<List<SyncQueueItem>> getPendingItems() async {
    return await _database.getPendingSyncItems();
  }

  /// Get pending items by entity type
  Future<List<SyncQueueItem>> getPendingItemsByType(SyncEntityType type) async {
    return await _database.getPendingSyncItemsByType(type);
  }

  /// Process all pending items in the queue
  Future<SyncQueueResult> processQueue() async {
    if (_isProcessing) {
      return SyncQueueResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    if (!_connectivity.isOnline) {
      return SyncQueueResult(
        success: false,
        message: 'No internet connection',
      );
    }

    _isProcessing = true;
    int processed = 0;
    int failed = 0;
    final errors = <String>[];

    try {
      final items = await _database.getPendingSyncItems();

      for (final item in items) {
        try {
          await _processItem(item);
          await _database.removeSyncQueueItem(item.id!);
          processed++;
        } catch (e) {
          failed++;
          errors.add('${item.description}: $e');

          // Update retry count
          final updatedItem = item.copyWithRetry(error: e.toString());

          if (updatedItem.hasExceededMaxRetries) {
            // Remove items that have exceeded max retries
            await _database.removeSyncQueueItem(item.id!);
            errors.add('${item.description} removed after max retries');
          } else {
            await _database.updateSyncQueueItem(updatedItem);
          }
        }
      }

      _notifyPendingCount();

      return SyncQueueResult(
        success: failed == 0,
        processed: processed,
        failed: failed,
        errors: errors,
        message: failed == 0
            ? 'All items synced successfully'
            : '$processed synced, $failed failed',
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single queue item
  Future<void> _processItem(SyncQueueItem item) async {
    switch (item.entityType) {
      case SyncEntityType.client:
        await _processClientItem(item);
        break;
      case SyncEntityType.order:
        await _processOrderItem(item);
        break;
      case SyncEntityType.visit:
        await _processVisitItem(item);
        break;
      case SyncEntityType.visitReport:
        await _processVisitReportItem(item);
        break;
      case SyncEntityType.alert:
        await _processAlertItem(item);
        break;
    }
  }

  /// Process client sync item
  Future<void> _processClientItem(SyncQueueItem item) async {
    switch (item.operation) {
      case SyncOperation.create:
        await _apiService.post('/api/clients', body: item.payload);
        break;
      case SyncOperation.update:
        if (item.entityId != null) {
          await _apiService.put('/api/clients/${item.entityId}', body: item.payload);
        }
        break;
      case SyncOperation.delete:
        // Clients typically aren't deleted, but handle if needed
        break;
    }
  }

  /// Process order sync item
  Future<void> _processOrderItem(SyncQueueItem item) async {
    switch (item.operation) {
      case SyncOperation.create:
        await _apiService.post('/api/orders', body: item.payload);
        break;
      case SyncOperation.update:
        if (item.entityId != null) {
          await _apiService.put('/api/orders/${item.entityId}', body: item.payload);
        }
        break;
      case SyncOperation.delete:
        break;
    }
  }

  /// Process visit sync item
  Future<void> _processVisitItem(SyncQueueItem item) async {
    switch (item.operation) {
      case SyncOperation.create:
        // Start visit
        await _apiService.post('/api/visits', body: item.payload);
        break;
      case SyncOperation.update:
        // End visit
        if (item.entityId != null) {
          await _apiService.put('/api/visits/${item.entityId}', body: item.payload);
        }
        break;
      case SyncOperation.delete:
        break;
    }
  }

  /// Process visit report sync item
  Future<void> _processVisitReportItem(SyncQueueItem item) async {
    if (item.operation == SyncOperation.create && item.entityId != null) {
      await _apiService.post('/api/visits/${item.entityId}/report', body: item.payload);
    }
  }

  /// Process alert sync item
  Future<void> _processAlertItem(SyncQueueItem item) async {
    switch (item.operation) {
      case SyncOperation.create:
        await _apiService.post('/api/alerts', body: item.payload);
        break;
      case SyncOperation.update:
        if (item.entityId != null) {
          // Check if this is a resolve operation
          if (item.payload['resolve'] == true) {
            await _apiService.post('/api/alerts/${item.entityId}/resolve', body: item.payload);
          } else {
            await _apiService.put('/api/alerts/${item.entityId}', body: item.payload);
          }
        }
        break;
      case SyncOperation.delete:
        break;
    }
  }

  /// Notify listeners of pending count change
  Future<void> _notifyPendingCount() async {
    final count = await getPendingCount();
    _pendingCountController.add(count);
  }

  /// Clear all pending items (use with caution)
  Future<void> clearQueue() async {
    await _database.clearSyncQueue();
    _notifyPendingCount();
  }

  /// Dispose resources
  void dispose() {
    _pendingCountController.close();
  }

  /// Reset singleton (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Result of processing the sync queue
class SyncQueueResult {
  final bool success;
  final int processed;
  final int failed;
  final List<String> errors;
  final String message;

  SyncQueueResult({
    required this.success,
    this.processed = 0,
    this.failed = 0,
    this.errors = const [],
    required this.message,
  });
}
