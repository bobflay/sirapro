import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/alert.dart';
import '../models/client.dart';
import '../models/visit_report.dart'; // For GeotaggedPhoto
import '../services/alert_service.dart';
import '../services/photo_capture_service.dart';
import '../utils/app_colors.dart';

/// Page de création d'une alerte - pleine page
class AlertCreationPage extends StatefulWidget {
  final Client? client; // Si création depuis une fiche client
  final Alert? existingAlert; // Si modification d'une alerte existante

  const AlertCreationPage({
    super.key,
    this.client,
    this.existingAlert,
  });

  @override
  State<AlertCreationPage> createState() => _AlertCreationPageState();
}

class _AlertCreationPageState extends State<AlertCreationPage> {
  final AlertService _alertService = AlertService();
  final PhotoCaptureService _photoService = PhotoCaptureService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  // Form values
  AlertType _selectedType = AlertType.other;
  AlertPriority _selectedPriority = AlertPriority.medium;
  final List<GeotaggedPhoto> _photos = [];
  GpsLocation? _gpsLocation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    // Si création depuis une fiche client
    if (widget.client != null) {
      _clientNameController.text = widget.client!.boutiqueName;
    }

    // Si modification d'une alerte existante
    if (widget.existingAlert != null) {
      final alert = widget.existingAlert!;
      setState(() {
        _titleController.text = alert.title;
        _descriptionController.text = alert.description;
        _clientNameController.text = alert.clientName ?? '';
        _commentController.text = alert.comment ?? '';
        _selectedType = alert.type;
        _selectedPriority = alert.priority;
        _gpsLocation = alert.location;
        // Note: photos would need to be reconstructed from URLs
      });
    }
  }

  Future<void> _capturePhoto() async {
    try {
      // Vérifier les permissions
      final permissionResult = await _photoService.checkAndRequestPermissions();

      if (!permissionResult.isGranted) {
        if (mounted) {
          if (permissionResult.isPermanentlyDenied) {
            _showPermissionDeniedDialog(permissionResult);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(permissionResult.message),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Réessayer',
                  textColor: Colors.white,
                  onPressed: _capturePhoto,
                ),
              ),
            );
          }
        }
        return;
      }

      final photo = await _photoService.takePhoto(
        description: 'Photo d\'alerte',
      );

      if (photo != null) {
        setState(() {
          _photos.add(photo);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo capturée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final permissionResult = await _photoService.checkAndRequestPermissions();

      if (!permissionResult.isGranted) {
        if (mounted) {
          if (permissionResult.isPermanentlyDenied) {
            _showPermissionDeniedDialog(permissionResult);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(permissionResult.message),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      final photo = await _photoService.pickFromGallery(
        description: 'Photo d\'alerte',
      );

      if (photo != null) {
        setState(() {
          _photos.add(photo);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo ajoutée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog(PermissionResult permissionResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Permissions requises'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              permissionResult.message,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pour activer les permissions sur iOS :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Allez dans Réglages > Confidentialité et sécurité'),
            const Text('2. Choisissez "Appareil photo" ou "Services de localisation"'),
            const Text('3. Activez la permission pour SIRA PRO'),
            const Text('4. Revenez à l\'application'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Ouvrir les paramètres'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto(int index) async {
    setState(() {
      if (index < _photos.length) {
        _photos.removeAt(index);
      }
    });
  }

  Future<void> _captureGpsLocation() async {
    try {
      setState(() => _isSubmitting = true);

      final position = await _photoService.getCurrentPosition();

      if (position != null) {
        setState(() {
          _gpsLocation = GpsLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Localisation GPS capturée'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Impossible d\'obtenir la position GPS');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur GPS: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_titleController.text.trim().isEmpty) {
      _showError('Veuillez saisir un titre');
      return false;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showError('Veuillez saisir une description');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submitAlert() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Convertir les photos en URLs (paths)
      final photoUrls = _photos.map((photo) => photo.path).toList();

      // Créer l'alerte
      final alert = Alert(
        id: widget.existingAlert?.id ?? _alertService.generateAlertId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        priority: _selectedPriority,
        clientId: widget.client?.id,
        clientName: _clientNameController.text.trim().isEmpty
            ? null
            : _clientNameController.text.trim(),
        createdAt: widget.existingAlert?.createdAt ?? DateTime.now(),
        photoUrls: photoUrls,
        location: _gpsLocation,
        status: AlertStatus.pending,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      final success = await _alertService.createAlert(alert);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alerte "${alert.title}" créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(alert);
      } else if (mounted) {
        throw Exception('Erreur lors de la création de l\'alerte');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingAlert != null ? 'Modifier l\'alerte' : 'Créer une alerte'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Informations principales
            _buildMainInfoSection(),
            const SizedBox(height: 20),

            // Photos
            _buildPhotosSection(),
            const SizedBox(height: 20),

            // Localisation GPS
            _buildGpsSection(),
            const SizedBox(height: 20),

            // Commentaires additionnels
            _buildCommentsSection(),
            const SizedBox(height: 30),

            // Bouton de soumission
            _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Informations de l\'alerte',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nom du client (at the beginning)
            const Text(
              'Nom du client',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                hintText: 'Nom du client concerné',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
                prefixIcon: Icon(Icons.store),
              ),
              enabled: widget.client == null,
            ),
            const SizedBox(height: 16),

            // Type d'alerte
            const Text(
              'Type d\'alerte *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AlertType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: AlertType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    _getAlertTypeLabel(type),
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Veuillez sélectionner un type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Priorité
            const Text(
              'Priorité *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<AlertPriority>(
              initialValue: _selectedPriority,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: AlertPriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _getPriorityColor(priority),
                      ),
                      const SizedBox(width: 8),
                      Text(_getAlertPriorityLabel(priority)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
              validator: (value) {
                if (value == null) {
                  return 'Veuillez sélectionner une priorité';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Titre
            const Text(
              'Titre *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Titre de l\'alerte',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir un titre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            const Text(
              'Description *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez l\'alerte en détail...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir une description';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.primary),
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
                  '${_photos.length} photo(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez des photos pour illustrer l\'alerte (optionnel)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Liste des photos
            if (_photos.isNotEmpty) ...[
              ..._photos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPhotoItem(photo, index),
                );
              }),
              const SizedBox(height: 8),
            ],

            // Boutons pour ajouter des photos
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Appareil photo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
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

  Widget _buildPhotoItem(GeotaggedPhoto photo, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photo ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Miniature de la photo
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(photo.path),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),

          // Informations GPS et timestamp
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatTime(photo.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              if (photo.latitude != null && photo.longitude != null) ...[
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Bouton supprimer
          TextButton.icon(
            onPressed: () => _removePhoto(index),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Supprimer'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSection() {
    return Card(
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
            const SizedBox(height: 8),
            const Text(
              'Capturez votre position actuelle (optionnel)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            if (_gpsLocation == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _captureGpsLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Capturer ma position'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Position GPS capturée',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: ${_gpsLocation!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Longitude: ${_gpsLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _gpsLocation = null;
                        });
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Card(
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
                  'Commentaires additionnels',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez des informations complémentaires (optionnel)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commentController,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Commentaires, contexte, actions prévues...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitAlert,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(
          _isSubmitting ? 'Création en cours...' : 'Créer l\'alerte',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
