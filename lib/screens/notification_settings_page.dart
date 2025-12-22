import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Notification preferences keys
  static const String _keyAllNotifications = 'notifications_all';
  static const String _keyOrderNotifications = 'notifications_orders';
  static const String _keyVisitNotifications = 'notifications_visits';
  static const String _keyAlertNotifications = 'notifications_alerts';
  static const String _keyStockNotifications = 'notifications_stock';
  static const String _keySyncNotifications = 'notifications_sync';

  // Notification states
  bool _allNotifications = true;
  bool _orderNotifications = true;
  bool _visitNotifications = true;
  bool _alertNotifications = true;
  bool _stockNotifications = true;
  bool _syncNotifications = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _allNotifications = prefs.getBool(_keyAllNotifications) ?? true;
      _orderNotifications = prefs.getBool(_keyOrderNotifications) ?? true;
      _visitNotifications = prefs.getBool(_keyVisitNotifications) ?? true;
      _alertNotifications = prefs.getBool(_keyAlertNotifications) ?? true;
      _stockNotifications = prefs.getBool(_keyStockNotifications) ?? true;
      _syncNotifications = prefs.getBool(_keySyncNotifications) ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _toggleAllNotifications(bool value) {
    setState(() {
      _allNotifications = value;
      if (!value) {
        // Disable all individual notifications
        _orderNotifications = false;
        _visitNotifications = false;
        _alertNotifications = false;
        _stockNotifications = false;
        _syncNotifications = false;
      } else {
        // Enable all individual notifications
        _orderNotifications = true;
        _visitNotifications = true;
        _alertNotifications = true;
        _stockNotifications = true;
        _syncNotifications = true;
      }
    });

    // Save all preferences
    _savePreference(_keyAllNotifications, value);
    _savePreference(_keyOrderNotifications, value);
    _savePreference(_keyVisitNotifications, value);
    _savePreference(_keyAlertNotifications, value);
    _savePreference(_keyStockNotifications, value);
    _savePreference(_keySyncNotifications, value);
  }

  void _toggleIndividualNotification(String key, bool value,
      void Function(bool) updateState) {
    setState(() {
      updateState(value);
      // Update "all notifications" toggle based on individual states
      _allNotifications = _orderNotifications &&
          _visitNotifications &&
          _alertNotifications &&
          _stockNotifications &&
          _syncNotifications;
    });

    _savePreference(key, value);
    _savePreference(_keyAllNotifications, _allNotifications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const SessionAwareAppBar(
        title: 'Paramètres des notifications',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Gérez vos préférences de notification pour rester informé des événements importants.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Master Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildNotificationToggle(
                        icon: Icons.notifications,
                        iconColor: Theme.of(context).primaryColor,
                        title: 'Toutes les notifications',
                        subtitle: 'Activer ou désactiver toutes les notifications',
                        value: _allNotifications,
                        onChanged: _toggleAllNotifications,
                        isMain: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Categories Section
                    const Text(
                      'Catégories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Individual toggles
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildNotificationToggle(
                            icon: Icons.shopping_cart,
                            iconColor: Colors.green,
                            title: 'Commandes',
                            subtitle: 'Nouvelles commandes et mises à jour',
                            value: _orderNotifications,
                            onChanged: (value) {
                              _toggleIndividualNotification(
                                _keyOrderNotifications,
                                value,
                                (v) => _orderNotifications = v,
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildNotificationToggle(
                            icon: Icons.location_on,
                            iconColor: Colors.blue,
                            title: 'Visites',
                            subtitle: 'Rappels et planification de visites',
                            value: _visitNotifications,
                            onChanged: (value) {
                              _toggleIndividualNotification(
                                _keyVisitNotifications,
                                value,
                                (v) => _visitNotifications = v,
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildNotificationToggle(
                            icon: Icons.warning_amber,
                            iconColor: Colors.orange,
                            title: 'Alertes',
                            subtitle: 'Alertes importantes et urgentes',
                            value: _alertNotifications,
                            onChanged: (value) {
                              _toggleIndividualNotification(
                                _keyAlertNotifications,
                                value,
                                (v) => _alertNotifications = v,
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildNotificationToggle(
                            icon: Icons.inventory,
                            iconColor: Colors.purple,
                            title: 'Stock',
                            subtitle: 'Alertes de stock faible',
                            value: _stockNotifications,
                            onChanged: (value) {
                              _toggleIndividualNotification(
                                _keyStockNotifications,
                                value,
                                (v) => _stockNotifications = v,
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildNotificationToggle(
                            icon: Icons.sync,
                            iconColor: Colors.teal,
                            title: 'Synchronisation',
                            subtitle: 'État de la synchronisation des données',
                            value: _syncNotifications,
                            onChanged: (value) {
                              _toggleIndividualNotification(
                                _keySyncNotifications,
                                value,
                                (v) => _syncNotifications = v,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reset button
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          _toggleAllNotifications(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paramètres réinitialisés'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réinitialiser les paramètres'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotificationToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isMain = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: isMain ? 28 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMain ? 17 : 16,
                    fontWeight: isMain ? FontWeight.bold : FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
            activeThumbColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      color: Colors.grey[200],
    );
  }
}
