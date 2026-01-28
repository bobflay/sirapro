import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/sync_queue_item.dart';
import '../api_service.dart';
import 'database_service.dart';
import 'connectivity_service.dart';
import 'sync_queue_service.dart';

/// Main orchestration service for offline functionality
class OfflineService {
  static OfflineService? _instance;

  final DatabaseService _database;
  final ConnectivityService _connectivity;
  final SyncQueueService _syncQueue;
  final ApiService _apiService;

  bool _initialized = false;
  StreamSubscription<bool>? _connectivitySubscription;

  final StreamController<OfflineState> _stateController = StreamController<OfflineState>.broadcast();
  OfflineState _currentState = OfflineState.unknown;

  // Sync status for each entity type
  final Map<String, SyncStatus> _syncStatuses = {};

  OfflineService._internal(
    this._database,
    this._connectivity,
    this._syncQueue,
    this._apiService,
  );

  factory OfflineService({
    DatabaseService? database,
    ConnectivityService? connectivity,
    SyncQueueService? syncQueue,
    ApiService? apiService,
  }) {
    _instance ??= OfflineService._internal(
      database ?? DatabaseService(),
      connectivity ?? ConnectivityService(),
      syncQueue ?? SyncQueueService(),
      apiService ?? ApiService(),
    );
    return _instance!;
  }

  // ==================== Getters ====================

  /// Current offline state
  OfflineState get state => _currentState;

  /// Check if currently online
  bool get isOnline => _connectivity.isOnline;

  /// Check if offline mode is available (not on web)
  bool get isOfflineModeAvailable => !kIsWeb;

  /// Stream of offline state changes
  Stream<OfflineState> get stateStream => _stateController.stream;

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream => _connectivity.connectivityStream;

  /// Get pending sync count
  Future<int> get pendingCount => _syncQueue.getPendingCount();

  /// Stream of pending counts
  Stream<int> get pendingCountStream => _syncQueue.pendingCountStream;

  /// Get sync status for all entity types
  Map<String, SyncStatus> get syncStatuses => Map.unmodifiable(_syncStatuses);

  /// Check if initialized
  bool get isInitialized => _initialized;

  // ==================== Initialization ====================

  /// Initialize the offline service
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip initialization on web
    if (kIsWeb) {
      _currentState = OfflineState.online;
      _initialized = true;
      return;
    }

    // Initialize connectivity monitoring
    await _connectivity.initialize();

    // Initialize database
    await _database.database;

    // Load sync statuses from database
    await _loadSyncStatuses();

    // Update state based on connectivity
    _updateState();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.connectivityStream.listen((isOnline) {
      _updateState();

      // Auto-sync when coming back online
      if (isOnline) {
        _onConnectivityRestored();
      }
    });

    _initialized = true;
  }

  /// Load sync statuses from database
  Future<void> _loadSyncStatuses() async {
    final statuses = await _database.getAllSyncMetadata();
    for (final status in statuses) {
      _syncStatuses[status.entityType] = status;
    }

    // Initialize missing entity types
    for (final type in ['clients', 'products', 'orders', 'visits', 'alerts', 'invoices', 'routing']) {
      _syncStatuses.putIfAbsent(type, () => SyncStatus(entityType: type));
    }
  }

  /// Update offline state based on connectivity
  void _updateState() {
    final newState = _connectivity.isOnline ? OfflineState.online : OfflineState.offline;
    if (newState != _currentState) {
      _currentState = newState;
      _stateController.add(_currentState);
    }
  }

  /// Handle connectivity restoration
  Future<void> _onConnectivityRestored() async {
    // Process pending queue items
    final pendingCount = await _syncQueue.getPendingCount();
    if (pendingCount > 0) {
      // Optionally auto-sync (can be made configurable)
      // await processPendingQueue();
    }
  }

  // ==================== Sync Operations ====================

  /// Sync all entities
  Future<SyncResult> syncAll({void Function(String, double)? onProgress}) async {
    if (!_connectivity.isOnline) {
      return SyncResult(success: false, message: 'Pas de connexion internet');
    }

    final results = <String, bool>{};
    final errors = <String>[];
    int completed = 0;
    const totalSteps = 7;

    try {
      // 1. Process pending queue first
      onProgress?.call('Envoi des données en attente...', completed / totalSteps);
      final queueResult = await processPendingQueue();
      if (!queueResult.success && queueResult.failed > 0) {
        errors.addAll(queueResult.errors);
      }
      completed++;

      // 2. Sync clients
      onProgress?.call('Synchronisation des clients...', completed / totalSteps);
      results['clients'] = await _syncClients();
      completed++;

      // 3. Sync products
      onProgress?.call('Synchronisation des produits...', completed / totalSteps);
      results['products'] = await _syncProducts();
      completed++;

      // 4. Sync orders
      onProgress?.call('Synchronisation des commandes...', completed / totalSteps);
      results['orders'] = await _syncOrders();
      completed++;

      // 5. Sync visits
      onProgress?.call('Synchronisation des visites...', completed / totalSteps);
      results['visits'] = await _syncVisits();
      completed++;

      // 6. Sync alerts
      onProgress?.call('Synchronisation des alertes...', completed / totalSteps);
      results['alerts'] = await _syncAlerts();
      completed++;

      // 7. Sync routing
      onProgress?.call('Synchronisation des tournées...', completed / totalSteps);
      results['routing'] = await _syncRouting();
      completed++;

      onProgress?.call('Terminé', 1.0);

      final allSuccess = results.values.every((v) => v);
      return SyncResult(
        success: allSuccess,
        message: allSuccess ? 'Synchronisation terminée' : 'Certaines données n\'ont pas pu être synchronisées',
        entityResults: results,
        errors: errors,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Erreur lors de la synchronisation: $e',
        entityResults: results,
        errors: [...errors, e.toString()],
      );
    }
  }

  /// Sync a specific entity type
  Future<bool> syncEntity(String entityType) async {
    if (!_connectivity.isOnline) return false;

    switch (entityType) {
      case 'clients':
        return await _syncClients();
      case 'products':
        return await _syncProducts();
      case 'orders':
        return await _syncOrders();
      case 'visits':
        return await _syncVisits();
      case 'alerts':
        return await _syncAlerts();
      case 'invoices':
        return await _syncInvoices();
      case 'routing':
        return await _syncRouting();
      default:
        return false;
    }
  }

  /// Process pending queue items
  Future<SyncQueueResult> processPendingQueue() async {
    return await _syncQueue.processQueue();
  }

  // ==================== Entity Sync Methods ====================

  Future<bool> _syncClients() async {
    try {
      _updateSyncStatus('clients', isSyncing: true);

      // Fetch all clients from API
      final response = await _apiService.get('/api/clients?limit=1000');
      final data = response as Map<String, dynamic>;
      final clients = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('clients', clients, 'id');

      _updateSyncStatus('clients', isSyncing: false, itemCount: clients.length);
      return true;
    } catch (e) {
      _updateSyncStatus('clients', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncProducts() async {
    try {
      _updateSyncStatus('products', isSyncing: true);

      // Fetch all products from API
      final response = await _apiService.get('/api/products?per_page=1000');
      final data = response as Map<String, dynamic>;
      final products = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('products', products, 'id');

      // Also sync categories
      try {
        final catResponse = await _apiService.get('/api/products/categories?top_level=true');
        final catData = catResponse as Map<String, dynamic>;
        final categories = (catData['data'] as List<dynamic>).cast<Map<String, dynamic>>();
        await _database.upsertAll('product_categories', categories, 'id');
      } catch (_) {
        // Categories are optional, don't fail the whole sync
      }

      _updateSyncStatus('products', isSyncing: false, itemCount: products.length);
      return true;
    } catch (e) {
      _updateSyncStatus('products', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncOrders() async {
    try {
      _updateSyncStatus('orders', isSyncing: true);

      // Fetch recent orders (last 30 days)
      final fromDate = DateTime.now().subtract(const Duration(days: 30));
      final response = await _apiService.get(
        '/api/orders?per_page=500&from_date=${fromDate.toIso8601String().split('T').first}',
      );
      final data = response as Map<String, dynamic>;
      final orders = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('orders', orders, 'id');

      _updateSyncStatus('orders', isSyncing: false, itemCount: orders.length);
      return true;
    } catch (e) {
      _updateSyncStatus('orders', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncVisits() async {
    try {
      _updateSyncStatus('visits', isSyncing: true);

      // Fetch recent visits (last 7 days)
      final fromDate = DateTime.now().subtract(const Duration(days: 7));
      final response = await _apiService.get(
        '/api/visits?per_page=200&from_date=${fromDate.toIso8601String().split('T').first}',
      );
      final data = response as Map<String, dynamic>;
      final visits = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('visits', visits, 'id');

      _updateSyncStatus('visits', isSyncing: false, itemCount: visits.length);
      return true;
    } catch (e) {
      _updateSyncStatus('visits', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncAlerts() async {
    try {
      _updateSyncStatus('alerts', isSyncing: true);

      // Fetch open alerts
      final response = await _apiService.get('/api/alerts?status=open&limit=200');
      final data = response as Map<String, dynamic>;
      final alerts = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('alerts', alerts, 'id');

      _updateSyncStatus('alerts', isSyncing: false, itemCount: alerts.length);
      return true;
    } catch (e) {
      _updateSyncStatus('alerts', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncInvoices() async {
    try {
      _updateSyncStatus('invoices', isSyncing: true);

      // Fetch recent invoices
      final response = await _apiService.get('/api/invoices?per_page=200');
      final data = response as Map<String, dynamic>;
      final invoices = (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();

      // Save to local database
      await _database.upsertAll('invoices', invoices, 'id');

      _updateSyncStatus('invoices', isSyncing: false, itemCount: invoices.length);
      return true;
    } catch (e) {
      _updateSyncStatus('invoices', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncRouting() async {
    try {
      _updateSyncStatus('routing', isSyncing: true);

      // Fetch today's routing
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _apiService.get('/api/routing/my?date=$today');
      final data = response as Map<String, dynamic>;

      // Save to local database
      await _database.saveRouting(today, data);

      final itemCount = (data['data']?['items'] as List?)?.length ?? 0;
      _updateSyncStatus('routing', isSyncing: false, itemCount: itemCount);
      return true;
    } catch (e) {
      _updateSyncStatus('routing', isSyncing: false, error: e.toString());
      return false;
    }
  }

  /// Update sync status for an entity type
  void _updateSyncStatus(
    String entityType, {
    bool? isSyncing,
    int? itemCount,
    String? error,
  }) {
    final current = _syncStatuses[entityType] ?? SyncStatus(entityType: entityType);
    _syncStatuses[entityType] = current.copyWith(
      lastSyncAt: isSyncing == false && error == null ? DateTime.now() : null,
      isSyncing: isSyncing,
      itemCount: itemCount,
      error: error,
    );

    // Persist to database if sync completed successfully
    if (isSyncing == false && error == null) {
      _database.updateSyncMetadata(
        entityType,
        lastSyncAt: DateTime.now(),
        itemCount: itemCount ?? current.itemCount,
      );
    }
  }

  // ==================== Queue Operations ====================

  /// Add operation to sync queue (for offline operations)
  Future<void> queueOperation({
    required SyncEntityType entityType,
    int? entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    await _syncQueue.enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  /// Get pending sync items
  Future<List<SyncQueueItem>> getPendingItems() async {
    return await _syncQueue.getPendingItems();
  }

  // ==================== Data Access ====================

  /// Get cached clients
  Future<List<Map<String, dynamic>>> getCachedClients() async {
    return await _database.getAll('clients');
  }

  /// Get cached products
  Future<List<Map<String, dynamic>>> getCachedProducts() async {
    return await _database.getAll('products');
  }

  /// Get cached orders
  Future<List<Map<String, dynamic>>> getCachedOrders() async {
    return await _database.getAll('orders');
  }

  /// Get cached visits
  Future<List<Map<String, dynamic>>> getCachedVisits() async {
    return await _database.getAll('visits');
  }

  /// Get cached alerts
  Future<List<Map<String, dynamic>>> getCachedAlerts() async {
    return await _database.getAll('alerts');
  }

  /// Get cached routing for a date
  Future<Map<String, dynamic>?> getCachedRouting(String date) async {
    return await _database.getRouting(date);
  }

  /// Get cached entity by ID
  Future<Map<String, dynamic>?> getCachedEntity(String table, int id) async {
    return await _database.getById(table, id);
  }

  /// Search cached clients
  Future<List<Map<String, dynamic>>> searchCachedClients(String query) async {
    return await _database.searchClients(query);
  }

  /// Search cached products
  Future<List<Map<String, dynamic>>> searchCachedProducts(String query) async {
    return await _database.searchProducts(query);
  }

  // ==================== Cleanup ====================

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _stateController.close();
    _syncQueue.dispose();
    _connectivity.dispose();
  }

  /// Reset all offline data (for logout)
  Future<void> resetAllData() async {
    await _database.resetDatabase();
    _syncStatuses.clear();
  }

  /// Reset singleton (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Offline state enum
enum OfflineState {
  unknown,
  online,
  offline,
  syncing,
}

/// Result of a full sync operation
class SyncResult {
  final bool success;
  final String message;
  final Map<String, bool> entityResults;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.entityResults = const {},
    this.errors = const [],
  });
}
