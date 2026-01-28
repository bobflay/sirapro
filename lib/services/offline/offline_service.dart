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

  /// Helper to extract data list from various API response formats
  List<Map<String, dynamic>> _extractDataList(Map<String, dynamic> response) {
    final data = response['data'];

    // Direct list in data
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    // Nested pagination format: { data: { data: [...], current_page: ... } }
    if (data is Map<String, dynamic>) {
      final nestedData = data['data'];
      if (nestedData is List) {
        return nestedData.whereType<Map<String, dynamic>>().toList();
      }
    }

    return [];
  }

  Future<bool> _syncClients() async {
    try {
      _updateSyncStatus('clients', isSyncing: true);

      // Fetch clients with pagination (API limit is 100)
      final List<Map<String, dynamic>> allClients = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get('/api/clients?page=$page&limit=100');
        final data = response as Map<String, dynamic>;
        final clients = _extractDataList(data);

        if (clients.isEmpty) {
          hasMore = false;
        } else {
          allClients.addAll(clients);
          // Check if there's more pages
          final meta = data['meta'] as Map<String, dynamic>?;
          final currentPage = meta?['current_page'] as int? ?? page;
          final lastPage = meta?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        // Safety limit to avoid infinite loops
        if (page > 50) hasMore = false;
      }

      // Save to local database
      if (allClients.isNotEmpty) {
        await _database.upsertAll('clients', allClients, 'id');
      }

      _updateSyncStatus('clients', isSyncing: false, itemCount: allClients.length);
      return true;
    } catch (e) {
      _updateSyncStatus('clients', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncProducts() async {
    try {
      _updateSyncStatus('products', isSyncing: true);

      // Fetch products with pagination
      final List<Map<String, dynamic>> allProducts = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get('/api/products?page=$page&per_page=100');
        final data = response as Map<String, dynamic>;
        final products = _extractDataList(data);

        if (products.isEmpty) {
          hasMore = false;
        } else {
          allProducts.addAll(products);
          // Check pagination in nested data structure
          final nestedData = data['data'] as Map<String, dynamic>?;
          final currentPage = nestedData?['current_page'] as int? ?? page;
          final lastPage = nestedData?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        if (page > 50) hasMore = false;
      }

      // Save to local database
      if (allProducts.isNotEmpty) {
        await _database.upsertAll('products', allProducts, 'id');
      }

      // Also sync categories
      try {
        final catResponse = await _apiService.get('/api/products/categories?top_level=true');
        final catData = catResponse as Map<String, dynamic>;
        final categories = _extractDataList(catData);
        if (categories.isNotEmpty) {
          await _database.upsertAll('product_categories', categories, 'id');
        }
      } catch (_) {
        // Categories are optional, don't fail the whole sync
      }

      _updateSyncStatus('products', isSyncing: false, itemCount: allProducts.length);
      return true;
    } catch (e) {
      _updateSyncStatus('products', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncOrders() async {
    try {
      _updateSyncStatus('orders', isSyncing: true);

      // Fetch recent orders (last 30 days) with pagination
      final fromDate = DateTime.now().subtract(const Duration(days: 30));
      final List<Map<String, dynamic>> allOrders = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get(
          '/api/orders?page=$page&per_page=100&from_date=${fromDate.toIso8601String().split('T').first}',
        );
        final data = response as Map<String, dynamic>;
        final orders = _extractDataList(data);

        if (orders.isEmpty) {
          hasMore = false;
        } else {
          allOrders.addAll(orders);
          final nestedData = data['data'] as Map<String, dynamic>?;
          final currentPage = nestedData?['current_page'] as int? ?? page;
          final lastPage = nestedData?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        if (page > 20) hasMore = false;
      }

      // Save to local database
      if (allOrders.isNotEmpty) {
        await _database.upsertAll('orders', allOrders, 'id');
      }

      _updateSyncStatus('orders', isSyncing: false, itemCount: allOrders.length);
      return true;
    } catch (e) {
      _updateSyncStatus('orders', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncVisits() async {
    try {
      _updateSyncStatus('visits', isSyncing: true);

      // Fetch recent visits (last 7 days) with pagination
      final fromDate = DateTime.now().subtract(const Duration(days: 7));
      final List<Map<String, dynamic>> allVisits = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get(
          '/api/visits?page=$page&per_page=100&from_date=${fromDate.toIso8601String().split('T').first}',
        );
        final data = response as Map<String, dynamic>;
        final visits = _extractDataList(data);

        if (visits.isEmpty) {
          hasMore = false;
        } else {
          allVisits.addAll(visits);
          final nestedData = data['data'] as Map<String, dynamic>?;
          final currentPage = nestedData?['current_page'] as int? ?? page;
          final lastPage = nestedData?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        if (page > 10) hasMore = false;
      }

      // Save to local database
      if (allVisits.isNotEmpty) {
        await _database.upsertAll('visits', allVisits, 'id');
      }

      _updateSyncStatus('visits', isSyncing: false, itemCount: allVisits.length);
      return true;
    } catch (e) {
      _updateSyncStatus('visits', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncAlerts() async {
    try {
      _updateSyncStatus('alerts', isSyncing: true);

      // Fetch open alerts with pagination
      final List<Map<String, dynamic>> allAlerts = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get('/api/alerts?page=$page&limit=100&status=open');
        final data = response as Map<String, dynamic>;
        final alerts = _extractDataList(data);

        if (alerts.isEmpty) {
          hasMore = false;
        } else {
          allAlerts.addAll(alerts);
          final meta = data['meta'] as Map<String, dynamic>?;
          final currentPage = meta?['current_page'] as int? ?? page;
          final lastPage = meta?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        if (page > 10) hasMore = false;
      }

      // Save to local database
      if (allAlerts.isNotEmpty) {
        await _database.upsertAll('alerts', allAlerts, 'id');
      }

      _updateSyncStatus('alerts', isSyncing: false, itemCount: allAlerts.length);
      return true;
    } catch (e) {
      _updateSyncStatus('alerts', isSyncing: false, error: e.toString());
      return false;
    }
  }

  Future<bool> _syncInvoices() async {
    try {
      _updateSyncStatus('invoices', isSyncing: true);

      // Fetch recent invoices with pagination
      final List<Map<String, dynamic>> allInvoices = [];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.get('/api/invoices?page=$page&per_page=100');
        final data = response as Map<String, dynamic>;
        final invoices = _extractDataList(data);

        if (invoices.isEmpty) {
          hasMore = false;
        } else {
          allInvoices.addAll(invoices);
          final nestedData = data['data'] as Map<String, dynamic>?;
          final currentPage = nestedData?['current_page'] as int? ?? page;
          final lastPage = nestedData?['last_page'] as int? ?? 1;
          hasMore = currentPage < lastPage;
          page++;
        }

        if (page > 10) hasMore = false;
      }

      // Save to local database
      if (allInvoices.isNotEmpty) {
        await _database.upsertAll('invoices', allInvoices, 'id');
      }

      _updateSyncStatus('invoices', isSyncing: false, itemCount: allInvoices.length);
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

      // Extract item count from routing response
      int itemCount = 0;
      final routingData = data['data'];
      if (routingData is Map<String, dynamic>) {
        final routing = routingData['routing'] as Map<String, dynamic>?;
        final items = routing?['routing_items'] as List?;
        itemCount = items?.length ?? 0;
      }

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
