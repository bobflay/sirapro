import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert.dart';
import '../services/alert_service.dart';
import '../utils/app_colors.dart';

/// Page de détail d'une alerte
class AlertDetailPage extends StatefulWidget {
  final Alert alert;

  const AlertDetailPage({
    super.key,
    required this.alert,
  });

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  final AlertService _alertService = AlertService();
  late Alert _alert;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de l\'alerte'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          if (_alert.status != AlertStatus.resolved)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _showResolveDialog,
              tooltip: 'Résoudre',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statut
            _buildHeader(),

            // Informations principales
            _buildMainInfo(),

            // Client (si présent)
            if (_alert.clientName != null) _buildClientInfo(),

            // Photos (si présentes)
            if (_alert.photoUrls.isNotEmpty) _buildPhotosSection(),

            // Localisation (si présente)
            if (_alert.location != null) _buildLocationSection(),

            // Commentaire (si présent)
            if (_alert.comment != null) _buildCommentSection(),

            // Historique
            _buildHistorySection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _alert.status != AlertStatus.resolved
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildHeader() {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (_alert.status) {
      case AlertStatus.pending:
        statusColor = AppColors.secondary;
        statusIcon = Icons.pending;
        statusLabel = 'En attente';
        break;
      case AlertStatus.inProgress:
        statusColor = AppColors.primary;
        statusIcon = Icons.autorenew;
        statusLabel = 'En cours';
        break;
      case AlertStatus.resolved:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusLabel = 'Résolue';
        break;
    }

    Color priorityColor = _getPriorityColor(_alert.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE30613), Color(0xFFFF3B47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _alert.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _alert.priorityLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Informations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Type', _alert.typeLabel, Icons.category),
            const Divider(),
            _buildInfoRow('Priorité', _alert.priorityLabel, Icons.priority_high),
            const Divider(),
            _buildInfoRow(
              'Créée le',
              DateFormat('dd/MM/yyyy à HH:mm').format(_alert.createdAt),
              Icons.calendar_today,
            ),
            if (_alert.resolvedAt != null) ...[
              const Divider(),
              _buildInfoRow(
                'Résolue le',
                DateFormat('dd/MM/yyyy à HH:mm').format(_alert.resolvedAt!),
                Icons.check_circle_outline,
              ),
            ],
            const Divider(height: 24),
            const Text(
              'Description',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _alert.description,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Client concerné',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _alert.clientName!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_alert.photoUrls.length} photo(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _alert.photoUrls.length,
              itemBuilder: (context, index) {
                final photoPath = _alert.photoUrls[index];
                return GestureDetector(
                  onTap: () => _showPhotoDialog(photoPath, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(photoPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    final location = _alert.location!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Localisation GPS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Latitude',
              location.latitude.toStringAsFixed(6),
              Icons.place,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Longitude',
              location.longitude.toStringAsFixed(6),
              Icons.place,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openInMaps(location.latitude, location.longitude),
                icon: const Icon(Icons.map),
                label: const Text('Ouvrir dans Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Commentaires',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _alert.comment!,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Historique',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHistoryItem(
              'Alerte créée',
              DateFormat('dd/MM/yyyy à HH:mm').format(_alert.createdAt),
              Icons.add_circle_outline,
              AppColors.accent,
            ),
            if (_alert.status == AlertStatus.inProgress) ...[
              const SizedBox(height: 12),
              _buildHistoryItem(
                'En cours de traitement',
                'En attente de résolution',
                Icons.autorenew,
                AppColors.primary,
              ),
            ],
            if (_alert.resolvedAt != null) ...[
              const SizedBox(height: 12),
              _buildHistoryItem(
                'Alerte résolue',
                DateFormat('dd/MM/yyyy à HH:mm').format(_alert.resolvedAt!),
                Icons.check_circle,
                AppColors.success,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_alert.status == AlertStatus.pending)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _markAsInProgress,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Commencer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (_alert.status == AlertStatus.pending) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showResolveDialog,
              icon: const Icon(Icons.check_circle),
              label: const Text('Résoudre'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsInProgress() async {
    final success = await _alertService.markAlertInProgress(_alert.id);
    if (success && mounted) {
      final updatedAlert = await _alertService.getAlertById(_alert.id);
      if (updatedAlert != null) {
        setState(() {
          _alert = updatedAlert;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte marquée en cours'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _showResolveDialog() async {
    final TextEditingController commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Résoudre l\'alerte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous marquer cette alerte comme résolue ?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Commentaire de résolution (optionnel)',
                hintText: 'Décrivez la solution apportée...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Résoudre'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final comment = commentController.text.trim().isEmpty
          ? null
          : commentController.text.trim();
      final success = await _alertService.resolveAlert(_alert.id, comment: comment);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte marquée comme résolue'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }

    commentController.dispose();
  }

  void _showPhotoDialog(String photoPath, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Photo ${index + 1}/${_alert.photoUrls.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ClipRRect(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getPriorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return AppColors.urgent;
      case AlertPriority.high:
        return AppColors.high;
      case AlertPriority.medium:
        return AppColors.medium;
      case AlertPriority.low:
        return AppColors.low;
    }
  }
}
