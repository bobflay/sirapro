import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/sync_queue_item.dart';

/// SQLite database service for offline data storage
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  /// Check if running on web (sqflite not supported)
  bool get isWebPlatform => kIsWeb;

  /// Get database instance
  Future<Database?> get database async {
    if (isWebPlatform) return null;
    _database ??= await _initDatabase();
    return _database;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sirapro_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Clients table
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Product categories table
    await db.execute('''
      CREATE TABLE product_categories (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Visits table
    await db.execute('''
      CREATE TABLE visits (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Alerts table
    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Routing table (for today's route)
    await db.execute('''
      CREATE TABLE routing (
        id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sync queue for pending operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Sync metadata to track last sync times
    await db.execute('''
      CREATE TABLE sync_metadata (
        entity_type TEXT PRIMARY KEY,
        last_sync_at TEXT,
        item_count INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_clients_updated ON clients(updated_at)');
    await db.execute('CREATE INDEX idx_orders_updated ON orders(updated_at)');
    await db.execute('CREATE INDEX idx_visits_updated ON visits(updated_at)');
    await db.execute('CREATE INDEX idx_sync_queue_type ON sync_queue(entity_type)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }

  // ==================== Generic CRUD Operations ====================

  /// Insert or update a record in a table
  Future<void> upsert(String table, int id, Map<String, dynamic> data) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      table,
      {
        'id': id,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or update multiple records
  Future<void> upsertAll(String table, List<Map<String, dynamic>> items, String idField) async {
    final db = await database;
    if (db == null) return;

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final item in items) {
      batch.insert(
        table,
        {
          'id': item[idField],
          'data': jsonEncode(item),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get a single record by ID
  Future<Map<String, dynamic>?> getById(String table, int id) async {
    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  /// Get all records from a table
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query(table, orderBy: 'updated_at DESC');
    return results
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Get records with pagination
  Future<List<Map<String, dynamic>>> getPaginated(
    String table, {
    int page = 1,
    int limit = 20,
  }) async {
    final db = await database;
    if (db == null) return [];

    final offset = (page - 1) * limit;
    final results = await db.query(
      table,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    return results
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Get count of records in a table
  Future<int> getCount(String table) async {
    final db = await database;
    if (db == null) return 0;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete a record by ID
  Future<void> deleteById(String table, int id) async {
    final db = await database;
    if (db == null) return;

    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all records from a table
  Future<void> clearTable(String table) async {
    final db = await database;
    if (db == null) return;

    await db.delete(table);
  }

  // ==================== Sync Queue Operations ====================

  /// Add item to sync queue
  Future<int> addToSyncQueue(SyncQueueItem item) async {
    final db = await database;
    if (db == null) return -1;

    return await db.insert('sync_queue', item.toMap());
  }

  /// Get all pending sync items
  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );

    return results.map((row) => SyncQueueItem.fromMap(row)).toList();
  }

  /// Get pending sync items by entity type
  Future<List<SyncQueueItem>> getPendingSyncItemsByType(SyncEntityType type) async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query(
      'sync_queue',
      where: 'entity_type = ?',
      whereArgs: [type.value],
      orderBy: 'created_at ASC',
    );

    return results.map((row) => SyncQueueItem.fromMap(row)).toList();
  }

  /// Get count of pending sync items
  Future<int> getPendingSyncCount() async {
    final db = await database;
    if (db == null) return 0;

    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Update sync queue item (for retry count)
  Future<void> updateSyncQueueItem(SyncQueueItem item) async {
    final db = await database;
    if (db == null || item.id == null) return;

    await db.update(
      'sync_queue',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Remove item from sync queue
  Future<void> removeSyncQueueItem(int id) async {
    final db = await database;
    if (db == null) return;

    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all sync queue items
  Future<void> clearSyncQueue() async {
    final db = await database;
    if (db == null) return;

    await db.delete('sync_queue');
  }

  // ==================== Sync Metadata Operations ====================

  /// Update sync metadata for an entity type
  Future<void> updateSyncMetadata(String entityType, {DateTime? lastSyncAt, int? itemCount}) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      'sync_metadata',
      {
        'entity_type': entityType,
        'last_sync_at': lastSyncAt?.toIso8601String(),
        'item_count': itemCount ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get sync metadata for an entity type
  Future<SyncStatus?> getSyncMetadata(String entityType) async {
    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      'sync_metadata',
      where: 'entity_type = ?',
      whereArgs: [entityType],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SyncStatus.fromMap(results.first);
  }

  /// Get all sync metadata
  Future<List<SyncStatus>> getAllSyncMetadata() async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query('sync_metadata');
    return results.map((row) => SyncStatus.fromMap(row)).toList();
  }

  // ==================== Routing Operations ====================

  /// Save routing for a specific date
  Future<void> saveRouting(String date, Map<String, dynamic> data) async {
    final db = await database;
    if (db == null) return;

    // Delete old routing data (keep only last 7 days)
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    await db.delete(
      'routing',
      where: 'date < ?',
      whereArgs: [cutoffDate.toIso8601String().split('T').first],
    );

    await db.insert(
      'routing',
      {
        'id': date.hashCode,
        'date': date,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get routing for a specific date
  Future<Map<String, dynamic>?> getRouting(String date) async {
    final db = await database;
    if (db == null) return null;

    final results = await db.query(
      'routing',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  // ==================== Search Operations ====================

  /// Search clients by name
  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query('clients');
    final allClients = results
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();

    // Filter in memory (SQLite JSON search is limited)
    final lowerQuery = query.toLowerCase();
    return allClients.where((client) {
      final name = (client['name'] as String? ?? '').toLowerCase();
      final managerName = (client['manager_name'] as String? ?? '').toLowerCase();
      final city = (client['city'] as String? ?? '').toLowerCase();
      return name.contains(lowerQuery) ||
          managerName.contains(lowerQuery) ||
          city.contains(lowerQuery);
    }).toList();
  }

  /// Search products by name
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    if (db == null) return [];

    final results = await db.query('products');
    final allProducts = results
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();

    final lowerQuery = query.toLowerCase();
    return allProducts.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final sku = (product['sku_global'] as String? ?? '').toLowerCase();
      return name.contains(lowerQuery) || sku.contains(lowerQuery);
    }).toList();
  }

  // ==================== Database Management ====================

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Delete and recreate database (for troubleshooting)
  Future<void> resetDatabase() async {
    if (isWebPlatform) return;

    final db = await database;
    if (db != null) {
      await db.close();
      _database = null;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sirapro_offline.db');
    await deleteDatabase(path);

    // Reinitialize
    _database = await _initDatabase();
  }

  /// Reset singleton (for testing)
  static void reset() {
    _instance = null;
    _database = null;
  }
}
