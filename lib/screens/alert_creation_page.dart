import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/client.dart';
import '../models/create_alert_request.dart';
import '../models/visit_report.dart'; // For GeotaggedPhoto
import '../services/alert_api_service.dart' show AlertApiService, AlertApiException, AlertPhotoData;
import '../services/photo_capture_service.dart';
import '../utils/app_colors.dart';
import '../widgets/session_aware_app_bar.dart';

/// Page de création d'une alerte - pleine page
class AlertCreationPage extends StatefulWidget {
  final Client? client; // Si création depuis une fiche client
  final int? visitId; // Si création depuis une visite
  final int? visitReportId; // Si création depuis un rapport de visite

  const AlertCreationPage({
    super.key,
    this.client,
    this.visitId,
    this.visitReportId,
  });

  @override
  State<AlertCreationPage> createState() => _AlertCreationPageState();
}

class _AlertCreationPageState extends State<AlertCreationPage> {
  final AlertApiService _alertApiService = AlertApiService();
  final PhotoCaptureService _photoService = PhotoCaptureService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _customTypeController = TextEditingController();

  // Form values
  String _selectedType = 'rupture_grave';
  final List<GeotaggedPhoto> _photos = [];
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
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
          _latitude = position.latitude;
          _longitude = position.longitude;
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

    if (_commentController.text.trim().isEmpty) {
      _showError('Veuillez saisir un commentaire');
      return false;
    }

    if (_latitude == null || _longitude == null) {
      _showError('Veuillez capturer votre position GPS');
      return false;
    }

    if (_selectedType == 'autre' && _customTypeController.text.trim().isEmpty) {
      _showError('Veuillez préciser le type d\'alerte');
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

    if (widget.client == null) {
      _showError('Client non spécifié');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final request = CreateAlertRequest(
        type: _selectedType,
        customType: _selectedType == 'autre' ? _customTypeController.text.trim() : null,
        comment: _commentController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        visitId: widget.visitId,
        visitReportId: widget.visitReportId,
      );

      // Prepare photo data and titles for upload
      final List<AlertPhotoData> photoDataList = [];
      final List<String> photoTitles = [];

      for (final photo in _photos) {
        if (photo.bytes != null) {
          photoDataList.add(AlertPhotoData(
            bytes: photo.bytes!,
            fileName: photo.effectiveFileName,
            mimeType: photo.mimeType,
          ));
          photoTitles.add(photo.description ?? 'Photo d\'alerte');
        }
      }

      final response = await _alertApiService.createAlertWithPhotos(
        clientId: widget.client!.id,
        request: request,
        photos: photoDataList.isNotEmpty ? photoDataList : null,
        photoTitles: photoTitles.isNotEmpty ? photoTitles : null,
      );

      if (response.status && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_photos.isNotEmpty
              ? 'Alerte créée avec ${_photos.length} photo(s)'
              : 'Alerte créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        throw Exception(response.message);
      }
    } on AlertApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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
      appBar: SessionAwareAppBar(
        title: 'Créer une alerte',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Client info
            if (widget.client != null) _buildClientInfo(),

            // Informations principales
            _buildMainInfoSection(),
            const SizedBox(height: 20),

            // Photos
            _buildPhotosSection(),
            const SizedBox(height: 20),

            // Localisation GPS
            _buildGpsSection(),
            const SizedBox(height: 30),

            // Bouton de soumission
            _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.store, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Client',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    widget.client!.boutiqueName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

            // Type d'alerte
            const Text(
              'Type d\'alerte *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: 'rupture_grave', child: Text('Rupture grave')),
                DropdownMenuItem(value: 'litige_probleme', child: Text('Litige / problème de paiement')),
                DropdownMenuItem(value: 'probleme_rayon', child: Text('Problème important au rayon')),
                DropdownMenuItem(value: 'risque_perte', child: Text('Risque de perte du client')),
                DropdownMenuItem(value: 'demande_speciale', child: Text('Demande spéciale du client')),
                DropdownMenuItem(value: 'opportunite', child: Text('Nouvelle opportunité importante')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
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

            // Custom type field (only if 'autre' selected)
            if (_selectedType == 'autre') ...[
              const SizedBox(height: 16),
              const Text(
                'Précisez le type *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  hintText: 'Décrivez le type d\'alerte',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (_selectedType == 'autre' && (value == null || value.trim().isEmpty)) {
                    return 'Veuillez préciser le type';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 16),

            // Commentaire
            const Text(
              'Commentaire *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Décrivez l\'alerte en détail...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez saisir un commentaire';
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
            child: kIsWeb
                ? Image.network(
                    photo.path,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  )
                : Image.file(
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
                  'Localisation GPS *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'La position GPS est requise pour créer une alerte',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            if (_latitude == null || _longitude == null)
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
                      'Latitude: ${_latitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Longitude: ${_longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _latitude = null;
                          _longitude = null;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Recapturer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
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
}
