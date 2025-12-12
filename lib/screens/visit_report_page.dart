import 'dart:io';
import 'package:flutter/material.dart';
import '../models/visit.dart';
import '../models/visit_report.dart';
import '../models/order.dart';
import '../models/client.dart';
import '../services/photo_capture_service.dart';
import 'package:geolocator/geolocator.dart';
import 'order_creation_page.dart';

/// Page de rapport de visite obligatoire
class VisitReportPage extends StatefulWidget {
  final Visit visit;
  final VisitReport? existingReport; // Si déjà commencé

  const VisitReportPage({
    super.key,
    required this.visit,
    this.existingReport,
  });

  @override
  State<VisitReportPage> createState() => _VisitReportPageState();
}

class _VisitReportPageState extends State<VisitReportPage> {
  final PhotoCaptureService _photoService = PhotoCaptureService();
  final _formKey = GlobalKey<FormState>();

  // Photos
  GeotaggedPhoto? _facadePhoto;
  GeotaggedPhoto? _shelfPhoto;
  List<GeotaggedPhoto> _additionalPhotos = [];

  // Champs du formulaire
  bool? _gerantPresent;
  bool? _orderPlaced;
  final TextEditingController _orderAmountController = TextEditingController();
  final TextEditingController _orderReferenceController = TextEditingController();
  final TextEditingController _stockShortagesController = TextEditingController();
  final TextEditingController _competitorActivityController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingReport();
  }

  @override
  void dispose() {
    _orderAmountController.dispose();
    _orderReferenceController.dispose();
    _stockShortagesController.dispose();
    _competitorActivityController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _loadExistingReport() {
    if (widget.existingReport != null) {
      final report = widget.existingReport!;
      setState(() {
        _facadePhoto = report.facadePhoto;
        _shelfPhoto = report.shelfPhoto;
        _additionalPhotos = List.from(report.additionalPhotos);
        _gerantPresent = report.gerantPresent;
        _orderPlaced = report.orderPlaced;
        _orderAmountController.text = report.orderAmount?.toString() ?? '';
        _orderReferenceController.text = report.orderReference ?? '';
        _stockShortagesController.text = report.stockShortages ?? '';
        _competitorActivityController.text = report.competitorActivity ?? '';
        _commentsController.text = report.comments ?? '';
      });
    }
  }

  Future<void> _capturePhoto(PhotoType type) async {
    try {
      final photo = await _photoService.takePhoto(
        description: type == PhotoType.facade
            ? 'Photo façade'
            : type == PhotoType.shelf
                ? 'Photo rayons'
                : 'Photo supplémentaire',
      );

      if (photo != null) {
        setState(() {
          switch (type) {
            case PhotoType.facade:
              _facadePhoto = photo;
              break;
            case PhotoType.shelf:
              _shelfPhoto = photo;
              break;
            case PhotoType.additional:
              _additionalPhotos.add(photo);
              break;
          }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto(PhotoType type, {int? index}) async {
    setState(() {
      switch (type) {
        case PhotoType.facade:
          _facadePhoto = null;
          break;
        case PhotoType.shelf:
          _shelfPhoto = null;
          break;
        case PhotoType.additional:
          if (index != null && index < _additionalPhotos.length) {
            _additionalPhotos.removeAt(index);
          }
          break;
      }
    });
  }

  bool _validateForm() {
    if (_facadePhoto == null) {
      _showError('La photo de façade est obligatoire');
      return false;
    }

    if (_shelfPhoto == null) {
      _showError('La photo des rayons est obligatoire');
      return false;
    }

    if (_gerantPresent == null) {
      _showError('Veuillez indiquer la présence du gérant');
      return false;
    }

    if (_orderPlaced == null) {
      _showError('Veuillez indiquer si une commande a été réalisée');
      return false;
    }

    if (_orderPlaced == true && _orderAmountController.text.trim().isEmpty) {
      _showError('Veuillez indiquer le montant de la commande');
      return false;
    }

    return _formKey.currentState?.validate() ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Obtenir la position GPS actuelle pour la validation
      Position? position = await _photoService.getCurrentPosition();

      if (position == null) {
        throw Exception('Impossible d\'obtenir la position GPS. Vérifiez que la localisation est activée.');
      }

      // Créer le rapport de visite
      final report = VisitReport(
        id: widget.existingReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        visitId: widget.visit.id,
        clientId: widget.visit.clientId,
        clientName: widget.visit.clientName,
        startTime: widget.visit.actualStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        validationLatitude: position.latitude,
        validationLongitude: position.longitude,
        validationTime: DateTime.now(),
        facadePhoto: _facadePhoto,
        shelfPhoto: _shelfPhoto,
        additionalPhotos: _additionalPhotos,
        gerantPresent: _gerantPresent,
        orderPlaced: _orderPlaced,
        orderAmount: _orderPlaced == true && _orderAmountController.text.trim().isNotEmpty
            ? double.tryParse(_orderAmountController.text.trim())
            : null,
        orderReference: _orderReferenceController.text.trim().isNotEmpty
            ? _orderReferenceController.text.trim()
            : null,
        stockShortages: _stockShortagesController.text.trim().isNotEmpty
            ? _stockShortagesController.text.trim()
            : null,
        competitorActivity: _competitorActivityController.text.trim().isNotEmpty
            ? _competitorActivityController.text.trim()
            : null,
        comments: _commentsController.text.trim().isNotEmpty
            ? _commentsController.text.trim()
            : null,
        status: VisitReportStatus.validated,
        createdAt: widget.existingReport?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Retourner le rapport validé
      if (mounted) {
        Navigator.of(context).pop(report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la validation: ${e.toString()}'),
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

  Future<void> _createOrder() async {
    // Create a temporary client object from visit information
    final client = Client(
      id: widget.visit.clientId,
      boutiqueName: widget.visit.clientName,
      type: 'Boutique', // Default type
      gerantName: '', // Unknown from visit
      phone: '', // Unknown from visit
      address: widget.visit.clientAddress,
      quartier: '',
      ville: '',
      status: 'Actif',
      isActive: true,
      createdAt: DateTime.now(),
    );

    // Navigate to order creation page
    final Order? order = await Navigator.push<Order>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCreationPage(
          client: client,
          visit: widget.visit,
        ),
      ),
    );

    if (order != null && mounted) {
      // Update order reference and amount
      setState(() {
        _orderReferenceController.text = order.id;
        _orderAmountController.text = order.totalAmount.toStringAsFixed(0);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande créée: ${order.formattedTotal}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport de Visite'),
        backgroundColor: Colors.blue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Informations client
            _buildClientInfoCard(),
            const SizedBox(height: 20),

            // Photos obligatoires
            _buildPhotosSection(),
            const SizedBox(height: 20),

            // Photos supplémentaires
            _buildAdditionalPhotosSection(),
            const SizedBox(height: 20),

            // Compte rendu
            _buildReportFieldsSection(),
            const SizedBox(height: 30),

            // Bouton de validation
            _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.visit.clientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.visit.clientAddress,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (widget.visit.actualStartTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Début: ${_formatTime(widget.visit.actualStartTime!)}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ],
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
            const Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Photos obligatoires',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Photo façade
            _buildPhotoItem(
              title: 'Photo Façade',
              photo: _facadePhoto,
              type: PhotoType.facade,
              required: true,
            ),
            const SizedBox(height: 12),

            // Photo rayons
            _buildPhotoItem(
              title: 'Photo Rayons / Linéaires',
              photo: _shelfPhoto,
              type: PhotoType.shelf,
              required: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalPhotosSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.add_photo_alternate, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Photos supplémentaires',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  '(optionnel)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Stock, anomalies, etc.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Liste des photos supplémentaires
            if (_additionalPhotos.isNotEmpty) ...[
              ..._additionalPhotos.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPhotoItem(
                    title: 'Photo ${entry.key + 1}',
                    photo: entry.value,
                    type: PhotoType.additional,
                    index: entry.key,
                    required: false,
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // Bouton ajouter une photo
            OutlinedButton.icon(
              onPressed: () => _capturePhoto(PhotoType.additional),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ajouter une photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem({
    required String title,
    required GeotaggedPhoto? photo,
    required PhotoType type,
    int? index,
    bool required = false,
  }) {
    final bool hasPhoto = photo != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasPhoto ? Colors.green : (required ? Colors.red : Colors.grey),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: hasPhoto ? Colors.green.withOpacity(0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (required)
                const Text(
                  '*',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (hasPhoto) ...[
            // Miniature de la photo
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                File(photo.path),
                height: 100,
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
              onPressed: () => _removePhoto(type, index: index),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
              ),
            ),
          ] else ...[
            // Bouton capturer
            ElevatedButton.icon(
              onPressed: () => _capturePhoto(type),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Prendre une photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportFieldsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Compte rendu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Présence du gérant
            const Text(
              'Présence du gérant *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Oui'),
                    value: true,
                    groupValue: _gerantPresent,
                    onChanged: (value) => setState(() => _gerantPresent = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Non'),
                    value: false,
                    groupValue: _gerantPresent,
                    onChanged: (value) => setState(() => _gerantPresent = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Commande réalisée
            const Text(
              'Commande réalisée *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Oui'),
                    value: true,
                    groupValue: _orderPlaced,
                    onChanged: (value) => setState(() => _orderPlaced = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Non'),
                    value: false,
                    groupValue: _orderPlaced,
                    onChanged: (value) => setState(() => _orderPlaced = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Montant de la commande (si Oui)
            if (_orderPlaced == true) ...[
              // Bouton pour créer une commande
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createOrder,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Créer une commande'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _orderAmountController,
                decoration: const InputDecoration(
                  labelText: 'Montant approximatif *',
                  hintText: 'Ex: 50000',
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_orderPlaced == true && (value == null || value.trim().isEmpty)) {
                    return 'Veuillez saisir le montant';
                  }
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value.trim()) == null) {
                      return 'Montant invalide';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Référence commande (optionnel)
              TextFormField(
                controller: _orderReferenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence commande (optionnel)',
                  hintText: 'Ex: CMD-2024-001',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Ruptures observées
            TextFormField(
              controller: _stockShortagesController,
              decoration: const InputDecoration(
                labelText: 'Ruptures observées (optionnel)',
                hintText: 'Produits en rupture de stock...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Activité concurrente
            TextFormField(
              controller: _competitorActivityController,
              decoration: const InputDecoration(
                labelText: 'Activité concurrente (optionnel)',
                hintText: 'Observations sur la concurrence...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Commentaires libres
            TextFormField(
              controller: _commentsController,
              decoration: const InputDecoration(
                labelText: 'Commentaires libres (optionnel)',
                hintText: 'Observations générales...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitReport,
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
          _isSubmitting ? 'Validation en cours...' : 'Valider la visite',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

enum PhotoType {
  facade,
  shelf,
  additional,
}
