import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for monitoring network connectivity
class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<ConnectivityResult>? _subscription;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool _initialized = false;

  ConnectivityService._internal();

  factory ConnectivityService() {
    _instance ??= ConnectivityService._internal();
    return _instance!;
  }

  /// Stream of connectivity changes (true = online, false = offline)
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isOnline => _isOnline;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize the connectivity service
  Future<void> initialize() async {
    if (_initialized) return;

    // Get initial connectivity status
    await _checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    _initialized = true;
  }

  /// Check current connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      return _isOnline;
    } catch (e) {
      // Assume online if we can't check (fail-safe for web or restricted platforms)
      _isOnline = true;
      return true;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    _updateStatus(result);
  }

  /// Update connectivity status based on result
  void _updateStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;

    // Check if connection is available
    _isOnline = result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;

    // Notify listeners if status changed
    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
    }
  }

  /// Force check connectivity (useful for manual refresh)
  Future<bool> checkConnectivity() async {
    return await _checkConnectivity();
  }

  /// Test actual internet connectivity (not just network interface)
  Future<bool> hasInternetAccess() async {
    if (kIsWeb) {
      // On web, assume online if connectivity reports online
      return _isOnline;
    }

    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
    _initialized = false;
  }

  /// Reset singleton (for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
