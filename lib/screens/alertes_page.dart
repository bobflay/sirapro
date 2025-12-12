import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sirapro/models/alert.dart';
import 'package:sirapro/services/alert_service.dart';
import 'package:sirapro/services/photo_capture_service.dart';
import 'package:intl/intl.dart';

class AlertesPage extends StatefulWidget {
  const AlertesPage({super.key});

  @override
  State<AlertesPage> createState() => _AlertesPageState();
}

class _AlertesPageState extends State<AlertesPage> {
  final AlertService _alertService = AlertService();
  List<Alert> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await _alertService.getPendingAlertsSorted();
    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Count alerts by priority
    final urgentPriority =
        _alerts.where((a) => a.priority == AlertPriority.urgent).length;
    final highPriority =
        _alerts.where((a) => a.priority == AlertPriority.high).length;
    final mediumPriority =
        _alerts.where((a) => a.priority == AlertPriority.medium).length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Alertes'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateAlertDialog(context),
            tooltip: 'Créer une alerte',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Priority Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        _buildPriorityBadge(
                          count: urgentPriority + highPriority,
                          label: 'Urgentes',
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _buildPriorityBadge(
                          count: mediumPriority,
                          label: 'Moyennes',
                          color: Colors.orange,
                        ),
                        const Spacer(),
                        Text(
                          '${_alerts.length} alertes',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Alerts List
                  Expanded(
                    child: _alerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucune alerte en attente',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showCreateAlertDialog(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Créer une alerte'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _alerts.length,
                              itemBuilder: (context, index) {
                                final alert = _alerts[index];
                                return _buildAlertCard(context, alert);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAlertDialog(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPriorityBadge({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert) {
    IconData icon;
    Color iconColor;

    switch (alert.type) {
      case AlertType.ruptureGrave:
        icon = Icons.inventory_2;
        iconColor = Colors.purple;
        break;
      case AlertType.litigeProbleme:
        icon = Icons.payment;
        iconColor = Colors.red;
        break;
      case AlertType.problemeRayon:
        icon = Icons.shelves;
        iconColor = Colors.orange;
        break;
      case AlertType.risquePerte:
        icon = Icons.warning;
        iconColor = Colors.red;
        break;
      case AlertType.demandeSpeciale:
        icon = Icons.star;
        iconColor = Colors.blue;
        break;
      case AlertType.opportunite:
        icon = Icons.lightbulb;
        iconColor = Colors.amber;
        break;
      case AlertType.other:
        icon = Icons.info;
        iconColor = Colors.teal;
        break;
    }

    Color priorityColor;
    switch (alert.priority) {
      case AlertPriority.urgent:
        priorityColor = Colors.red[900]!;
        break;
      case AlertPriority.high:
        priorityColor = Colors.red;
        break;
      case AlertPriority.medium:
        priorityColor = Colors.orange;
        break;
      case AlertPriority.low:
        priorityColor = Colors.grey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: (alert.priority == AlertPriority.urgent ||
                alert.priority == AlertPriority.high)
            ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and priority
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              alert.priorityLabel,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.typeLabel,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.description,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      if (alert.clientName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert.clientName!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (alert.photoUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.photo,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${alert.photoUrls.length} photo(s)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (alert.location != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'GPS: ${alert.location!.latitude.toStringAsFixed(4)}, ${alert.location!.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(alert.createdAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _resolveAlert(alert),
                  child: const Text('Résoudre'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showAlertDetails(alert),
                  child: const Text('Détails'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final alertDate = DateTime(date.year, date.month, date.day);

    if (alertDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (alertDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<void> _resolveAlert(Alert alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Résoudre l\'alerte'),
        content: const Text('Voulez-vous marquer cette alerte comme résolue ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Résoudre'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _alertService.resolveAlert(alert.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte marquée comme résolue'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAlerts();
      }
    }
  }

  void _showAlertDetails(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', alert.typeLabel),
              _buildDetailRow('Priorité', alert.priorityLabel),
              _buildDetailRow('Description', alert.description),
              if (alert.clientName != null)
                _buildDetailRow('Client', alert.clientName!),
              _buildDetailRow(
                  'Créée le', DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt)),
              if (alert.photoUrls.isNotEmpty)
                _buildDetailRow('Photos', '${alert.photoUrls.length} photo(s)'),
              if (alert.location != null)
                _buildDetailRow(
                  'Localisation',
                  '${alert.location!.latitude.toStringAsFixed(6)}, ${alert.location!.longitude.toStringAsFixed(6)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateAlertDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController clientNameController = TextEditingController();
    AlertType selectedType = AlertType.other;
    AlertPriority selectedPriority = AlertPriority.medium;
    List<String> photoUrls = [];
    GpsLocation? gpsLocation;
    bool captureGps = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Créer une alerte'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type dropdown
                const Text(
                  'Type d\'alerte',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AlertType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  items: AlertType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              _getAlertTypeLabel(type),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Priority dropdown
                const Text(
                  'Priorité',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AlertPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: AlertPriority.values
                      .map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(_getAlertPriorityLabel(priority)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPriority = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Title field
                const Text(
                  'Titre',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'Titre de l\'alerte',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Description field
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Décrivez l\'alerte...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Client name (optional)
                const Text(
                  'Nom du client (optionnel)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clientNameController,
                  decoration: const InputDecoration(
                    hintText: 'Nom du client',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Photo capture
                Row(
                  children: [
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${photoUrls.length} photo(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final photo = await PhotoCaptureService()
                              .takePhoto();
                          if (photo != null) {
                            setState(() {
                              photoUrls.add(photo.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: const Text('Appareil photo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final photo = await PhotoCaptureService()
                              .pickFromGallery();
                          if (photo != null) {
                            setState(() {
                              photoUrls.add(photo.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: const Text('Galerie'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // GPS location
                Row(
                  children: [
                    const Text(
                      'Capturer la localisation GPS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: captureGps,
                      onChanged: (value) async {
                        if (value) {
                          try {
                            final position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );
                            setState(() {
                              captureGps = true;
                              gpsLocation = GpsLocation(
                                latitude: position.latitude,
                                longitude: position.longitude,
                                timestamp: DateTime.now(),
                              );
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Impossible de capturer la localisation'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setState(() {
                              captureGps = false;
                            });
                          }
                        } else {
                          setState(() {
                            captureGps = false;
                            gpsLocation = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (gpsLocation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS: ${gpsLocation!.latitude.toStringAsFixed(4)}, ${gpsLocation!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                descriptionController.dispose();
                clientNameController.dispose();
                Navigator.pop(context, false);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez saisir un titre'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez saisir une description'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer alerte'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Create the alert
      final alert = Alert(
        id: _alertService.generateAlertId(),
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        type: selectedType,
        priority: selectedPriority,
        clientName: clientNameController.text.trim().isEmpty
            ? null
            : clientNameController.text.trim(),
        createdAt: DateTime.now(),
        photoUrls: photoUrls,
        location: gpsLocation,
      );

      final success = await _alertService.createAlert(alert);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alerte "${alert.title}" créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAlerts();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création de l\'alerte'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    titleController.dispose();
    descriptionController.dispose();
    clientNameController.dispose();
  }

  String _getAlertTypeLabel(AlertType type) {
    switch (type) {
      case AlertType.ruptureGrave:
        return 'Rupture grave';
      case AlertType.litigeProbleme:
        return 'Litige / problème de paiement';
      case AlertType.problemeRayon:
        return 'Problème important au rayon';
      case AlertType.risquePerte:
        return 'Risque de perte du client';
      case AlertType.demandeSpeciale:
        return 'Demande spéciale du client';
      case AlertType.opportunite:
        return 'Nouvelle opportunité importante';
      case AlertType.other:
        return 'Autre';
    }
  }

  String _getAlertPriorityLabel(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return 'Urgente';
      case AlertPriority.high:
        return 'Haute';
      case AlertPriority.medium:
        return 'Moyenne';
      case AlertPriority.low:
        return 'Faible';
    }
  }
}
