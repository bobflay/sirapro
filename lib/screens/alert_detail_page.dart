import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/api_alert.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/session_aware_app_bar.dart';

/// Page de détail d'une alerte
class AlertDetailPage extends StatefulWidget {
  final ApiAlert alert;

  const AlertDetailPage({
    super.key,
    required this.alert,
  });

  @override
  State<AlertDetailPage> createState() => _AlertDetailPageState();
}

class _AlertDetailPageState extends State<AlertDetailPage> {
  late ApiAlert _alert;

  @override
  void initState() {
    super.initState();
    _alert = widget.alert;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SessionAwareAppBar(
        title: 'Détails de l\'alerte',
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
            if (_alert.client != null) _buildClientInfo(),

            // Photos (si présentes)
            if (_alert.photos.isNotEmpty) _buildPhotosSection(),

            // Localisation (si présente)
            if (_alert.latitude != null && _alert.longitude != null)
              _buildLocationSection(),

            // Handler info (si présent)
            if (_alert.handler != null) _buildHandlerSection(),

            // Historique
            _buildHistorySection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final statusInfo = _getStatusInfo(_alert.status);

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
          Text(
            _alert.typeLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusInfo['icon'] as IconData, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _alert.statusLabel,
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            _buildInfoRow('Statut', _alert.statusLabel, Icons.flag),
            const Divider(),
            _buildInfoRow(
              'Créée le',
              DateFormat('dd/MM/yyyy à HH:mm').format(_alert.createdAt),
              Icons.calendar_today,
            ),
            if (_alert.alertedAt != null) ...[
              const Divider(),
              _buildInfoRow(
                'Alertée le',
                DateFormat('dd/MM/yyyy à HH:mm').format(_alert.alertedAt!),
                Icons.notifications,
              ),
            ],
            if (_alert.handledAt != null) ...[
              const Divider(),
              _buildInfoRow(
                'Traitée le',
                DateFormat('dd/MM/yyyy à HH:mm').format(_alert.handledAt!),
                Icons.check_circle_outline,
              ),
            ],
            const Divider(height: 24),
            const Text(
              'Commentaire',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _alert.comment,
              style: const TextStyle(fontSize: 15),
            ),
            if (_alert.handlingComment != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Commentaire de traitement',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _alert.handlingComment!,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    final client = _alert.client!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            Text(
              client.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (client.code != null) ...[
              const SizedBox(height: 4),
              Text(
                'Code: ${client.code}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (client.type != null) ...[
              const SizedBox(height: 4),
              Text(
                'Type: ${client.type}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (client.city != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_city, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    client.city!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  '${_alert.photos.length} photo(s)',
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
              itemCount: _alert.photos.length,
              itemBuilder: (context, index) {
                final photo = _alert.photos[index];
                final photoUrl = photo.url != null
                    ? '${ApiService.baseUrl}${photo.url}'
                    : null;

                return GestureDetector(
                  onTap: () => _showPhotoDialog(photo, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
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
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              _alert.latitude!.toStringAsFixed(6),
              Icons.place,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Longitude',
              _alert.longitude!.toStringAsFixed(6),
              Icons.place,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openInMaps(_alert.latitude!, _alert.longitude!),
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

  Widget _buildHandlerSection() {
    final handler = _alert.handler!;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Traité par',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              handler.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_alert.handledAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Le ${DateFormat('dd/MM/yyyy à HH:mm').format(_alert.handledAt!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
            if (_alert.status == 'in_progress') ...[
              const SizedBox(height: 12),
              _buildHistoryItem(
                'En cours de traitement',
                _alert.handler != null ? 'Par ${_alert.handler!.name}' : 'En attente de résolution',
                Icons.autorenew,
                AppColors.primary,
              ),
            ],
            if (_alert.handledAt != null) ...[
              const SizedBox(height: 12),
              _buildHistoryItem(
                'Alerte traitée',
                DateFormat('dd/MM/yyyy à HH:mm').format(_alert.handledAt!),
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

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'color': AppColors.secondary,
          'icon': Icons.pending,
        };
      case 'in_progress':
        return {
          'color': AppColors.primary,
          'icon': Icons.autorenew,
        };
      case 'resolved':
        return {
          'color': AppColors.success,
          'icon': Icons.check_circle,
        };
      default:
        return {
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  void _showPhotoDialog(ApiAlertPhoto photo, int index) {
    final photoUrl = photo.url != null
        ? '${ApiService.baseUrl}${photo.url}'
        : null;

    if (photoUrl == null) return;

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
                    photo.title ?? 'Photo ${index + 1}/${_alert.photos.length}',
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
            Image.network(
              photoUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.error, size: 48)),
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
}
