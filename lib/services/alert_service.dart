import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/models/alert.dart';
import '../data/mock_alerts.dart';

class AlertService {
  static const String _alertsKey = 'alerts';
  static const String _mockAlertsInitializedKey = 'mock_alerts_initialized';
  static AlertService? _instance;

  // Singleton pattern
  factory AlertService() {
    _instance ??= AlertService._internal();
    return _instance!;
  }

  AlertService._internal();

  // Initialize mock alerts on first run
  Future<void> _initializeMockAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isInitialized = prefs.getBool(_mockAlertsInitializedKey) ?? false;

      if (!isInitialized) {
        // Load mock alerts
        final mockAlertsData = getAllAlerts();
        await _saveAlerts(mockAlertsData);
        await prefs.setBool(_mockAlertsInitializedKey, true);
      }
    } catch (e) {
      print('Error initializing mock alerts: $e');
    }
  }

  // Get all alerts (including mock data)
  Future<List<Alert>> getAlerts() async {
    try {
      // Initialize mock alerts if needed
      await _initializeMockAlerts();

      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString(_alertsKey);

      if (alertsJson == null || alertsJson.isEmpty) {
        // Return mock alerts if no stored alerts
        return getAllAlerts();
      }

      final List<dynamic> alertsList = jsonDecode(alertsJson);
      return alertsList.map((json) => Alert.fromJson(json)).toList();
    } catch (e) {
      print('Error loading alerts: $e');
      // Fallback to mock alerts on error
      return getAllAlerts();
    }
  }

  // Get alerts filtered by status
  Future<List<Alert>> getAlertsByStatus(AlertStatus status) async {
    final alerts = await getAlerts();
    return alerts.where((alert) => alert.status == status).toList();
  }

  // Get alerts filtered by priority
  Future<List<Alert>> getAlertsByPriority(AlertPriority priority) async {
    final alerts = await getAlerts();
    return alerts.where((alert) => alert.priority == priority).toList();
  }

  // Get alerts for a specific client
  Future<List<Alert>> getAlertsForClient(String clientId) async {
    final alerts = await getAlerts();
    return alerts.where((alert) => alert.clientId == clientId).toList();
  }

  // Get alert by ID
  Future<Alert?> getAlertById(String id) async {
    final alerts = await getAlerts();
    try {
      return alerts.firstWhere((alert) => alert.id == id);
    } catch (e) {
      return null;
    }
  }

  // Create a new alert
  Future<bool> createAlert(Alert alert) async {
    try {
      final alerts = await getAlerts();
      alerts.add(alert);
      return await _saveAlerts(alerts);
    } catch (e) {
      print('Error creating alert: $e');
      return false;
    }
  }

  // Update an existing alert
  Future<bool> updateAlert(Alert updatedAlert) async {
    try {
      final alerts = await getAlerts();
      final index = alerts.indexWhere((a) => a.id == updatedAlert.id);

      if (index == -1) {
        return false; // Alert not found
      }

      alerts[index] = updatedAlert;
      return await _saveAlerts(alerts);
    } catch (e) {
      print('Error updating alert: $e');
      return false;
    }
  }

  // Delete an alert
  Future<bool> deleteAlert(String alertId) async {
    try {
      final alerts = await getAlerts();
      alerts.removeWhere((alert) => alert.id == alertId);
      return await _saveAlerts(alerts);
    } catch (e) {
      print('Error deleting alert: $e');
      return false;
    }
  }

  // Resolve an alert
  Future<bool> resolveAlert(String alertId, {String? comment}) async {
    try {
      final alert = await getAlertById(alertId);
      if (alert == null) {
        return false;
      }

      final updatedAlert = alert.copyWith(
        status: AlertStatus.resolved,
        resolvedAt: DateTime.now(),
        comment: comment,
      );

      return await updateAlert(updatedAlert);
    } catch (e) {
      print('Error resolving alert: $e');
      return false;
    }
  }

  // Mark alert as in progress
  Future<bool> markAlertInProgress(String alertId) async {
    try {
      final alert = await getAlertById(alertId);
      if (alert == null) {
        return false;
      }

      final updatedAlert = alert.copyWith(status: AlertStatus.inProgress);
      return await updateAlert(updatedAlert);
    } catch (e) {
      print('Error marking alert in progress: $e');
      return false;
    }
  }

  // Get statistics
  Future<Map<String, int>> getAlertStatistics() async {
    final alerts = await getAlerts();

    return {
      'total': alerts.length,
      'pending': alerts.where((a) => a.status == AlertStatus.pending).length,
      'inProgress':
          alerts.where((a) => a.status == AlertStatus.inProgress).length,
      'resolved': alerts.where((a) => a.status == AlertStatus.resolved).length,
      'urgent':
          alerts.where((a) => a.priority == AlertPriority.urgent).length,
      'high': alerts.where((a) => a.priority == AlertPriority.high).length,
      'medium':
          alerts.where((a) => a.priority == AlertPriority.medium).length,
      'low': alerts.where((a) => a.priority == AlertPriority.low).length,
    };
  }

  // Sort alerts by priority (urgent first) and then by creation date
  List<Alert> sortAlertsByPriority(List<Alert> alerts) {
    alerts.sort((a, b) {
      // First sort by priority (urgent = 0, high = 1, medium = 2, low = 3)
      final priorityComparison = a.priority.index.compareTo(b.priority.index);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      // If same priority, sort by date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
    return alerts;
  }

  // Get pending alerts sorted by priority
  Future<List<Alert>> getPendingAlertsSorted() async {
    final alerts = await getAlertsByStatus(AlertStatus.pending);
    return sortAlertsByPriority(alerts);
  }

  // Private method to save alerts to SharedPreferences
  Future<bool> _saveAlerts(List<Alert> alerts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = jsonEncode(alerts.map((a) => a.toJson()).toList());
      return await prefs.setString(_alertsKey, alertsJson);
    } catch (e) {
      print('Error saving alerts: $e');
      return false;
    }
  }

  // Clear all alerts (for testing/debugging)
  Future<bool> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_alertsKey);
    } catch (e) {
      print('Error clearing alerts: $e');
      return false;
    }
  }

  // Generate a unique ID for new alerts
  String generateAlertId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}';
  }
}
