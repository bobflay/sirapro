import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/visit.dart';
import '../models/visit_report.dart';
import '../models/client.dart';
import '../services/photo_capture_service.dart';
import '../services/product_service.dart';
import '../services/visit_api_service.dart';
import '../services/offline_queue_service.dart';
import '../widgets/session_aware_app_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'create_order_page.dart';

/// Page de rapport de visite obligatoire
class VisitReportPage extends StatefulWidget {
  final Visit visit;
  final VisitReport? existingReport; // Si déjà commencé
  final int? apiVisitId; // The actual API visit ID for submitting reports

  const VisitReportPage({
    super.key,
    required this.visit,
    this.existingReport,
    this.apiVisitId,
  });

  @override
  State<VisitReportPage> createState() => _VisitReportPageState();
}

class _VisitReportPageState extends State<VisitReportPage> {
  final PhotoCaptureService _photoService = PhotoCaptureService();
  final VisitApiService _visitApiService = VisitApiService();
  final _formKey = GlobalKey<FormState>();

  // Photos - now supporting multiple photos per category
  List<GeotaggedPhoto> _shelfPhotos = [];
  List<GeotaggedPhoto> _additionalPhotos = [];

  // Champs du formulaire
  bool? _gerantPresent;
  bool? _orderPlaced;
  bool? _needsOrder;
  final TextEditingController _orderAmountController = TextEditingController();
  final TextEditingController _orderReferenceController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  // Ruptures observées
  final List<String> _stockShortageOptions = [
    'Coca-Cola',
    'Fanta',
    'Sprite',
    'Eau minérale',
    'Jus de fruits',
    'Biscuits',
    'Bonbons',
    'Autre',
  ];
  List<String> _selectedStockShortages = [];
  final TextEditingController _stockShortagesOtherController = TextEditingController();

  // Activité concurrente
  final List<String> _competitorActivityOptions = [
    'Promotion Pepsi',
    'Nouveau distributeur',
    'Prix réduits',
    'Publicité visible',
    'Stock important',
    'Autre',
  ];
  List<String> _selectedCompetitorActivities = [];
  final TextEditingController _competitorActivityOtherController = TextEditingController();

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
    _stockShortagesOtherController.dispose();
    _competitorActivityOtherController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  void _loadExistingReport() {
    if (widget.existingReport != null) {
      final report = widget.existingReport!;
      setState(() {
        // Load photos - support both old single photo and new multiple photos format
        _shelfPhotos = List.from(report.allShelfPhotos);
        _additionalPhotos = List.from(report.additionalPhotos);
        _gerantPresent = report.gerantPresent;
        _orderPlaced = report.orderPlaced;
        _needsOrder = report.needsOrder;
        _orderAmountController.text = report.orderAmount?.toString() ?? '';
        _orderReferenceController.text = report.orderReference ?? '';

        // Parse stockShortages from string to list
        if (report.stockShortages != null && report.stockShortages!.isNotEmpty) {
          _selectedStockShortages = report.stockShortages!.split(', ');
        }

        // Parse competitorActivity from string to list
        if (report.competitorActivity != null && report.competitorActivity!.isNotEmpty) {
          _selectedCompetitorActivities = report.competitorActivity!.split(', ');
        }

        _commentsController.text = report.comments ?? '';
      });
    }
  }

  Future<void> _capturePhoto(PhotoType type) async {
    try {
      // Vérifier d'abord les permissions
      final permissionResult = await _photoService.checkAndRequestPermissions();

      if (!permissionResult.isGranted) {
        if (mounted) {
          // Si les permissions sont refusées de manière permanente, montrer le dialogue
          if (permissionResult.isPermanentlyDenied) {
            _showPermissionDeniedDialog(permissionResult);
          } else {
            // Sinon, afficher simplement le message d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(permissionResult.message),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Réessayer',
                  textColor: Colors.white,
                  onPressed: () => _capturePhoto(type),
                ),
              ),
            );
          }
        }
        return;
      }

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
              // Facade photos removed - no longer needed
              break;
            case PhotoType.shelf:
              _shelfPhotos.add(photo);
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
        String errorMessage = e.toString();
        // Extraire le message d'erreur si c'est une Exception
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

  /// Affiche un dialogue pour expliquer comment activer les permissions
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

  Future<void> _removePhoto(PhotoType type, {int? index}) async {
    setState(() {
      switch (type) {
        case PhotoType.facade:
          // Facade photos removed - no longer needed
          break;
        case PhotoType.shelf:
          if (index != null && index < _shelfPhotos.length) {
            _shelfPhotos.removeAt(index);
          }
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
    if (_shelfPhotos.isEmpty) {
      _showError('Au moins une photo des rayons est obligatoire');
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
    debugPrint('=== _submitReport started ===');
    debugPrint('widget.apiVisitId: ${widget.apiVisitId}');
    debugPrint('widget.visit.id: ${widget.visit.id}');
    debugPrint('Shelf photos count: ${_shelfPhotos.length}');
    debugPrint('Additional photos count: ${_additionalPhotos.length}');

    if (!_validateForm()) {
      debugPrint('Form validation failed');
      return;
    }
    debugPrint('Form validation passed');

    setState(() {
      _isSubmitting = true;
    });

    Position? position;
    String? stockShortagesText;
    String? competitorActivityText;
    int? visitId = widget.apiVisitId;

    try {
      // Obtenir la position GPS actuelle pour la validation
      debugPrint('Getting current GPS position...');
      position = await _photoService.getCurrentPosition();

      if (position == null) {
        debugPrint('GPS position is null');
        throw Exception('Impossible d\'obtenir la position GPS. Vérifiez que la localisation est activée.');
      }
      debugPrint('GPS position: ${position.latitude}, ${position.longitude}');

      // Build stock shortages string
      if (_selectedStockShortages.isNotEmpty) {
        List<String> shortages = List.from(_selectedStockShortages);
        if (_selectedStockShortages.contains('Autre') && _stockShortagesOtherController.text.trim().isNotEmpty) {
          shortages.remove('Autre');
          shortages.add(_stockShortagesOtherController.text.trim());
        }
        stockShortagesText = shortages.join(', ');
      }
      debugPrint('Stock shortages: $stockShortagesText');

      // Build competitor activity string
      debugPrint('Building competitor activity text...');
      if (_selectedCompetitorActivities.isNotEmpty) {
        List<String> activities = List.from(_selectedCompetitorActivities);
        if (_selectedCompetitorActivities.contains('Autre') && _competitorActivityOtherController.text.trim().isNotEmpty) {
          activities.remove('Autre');
          activities.add(_competitorActivityOtherController.text.trim());
        }
        competitorActivityText = activities.join(', ');
      }
      debugPrint('Competitor activity: $competitorActivityText');

      // Use GeotaggedPhoto objects directly for cross-platform API submission
      debugPrint('Preparing photos for upload...');
      debugPrint('_shelfPhotos: ${_shelfPhotos.length} photos');
      debugPrint('_additionalPhotos: ${_additionalPhotos.length} photos');

      // Verify all photos have bytes
      for (var p in _shelfPhotos) {
        debugPrint('  Shelf photo: ${p.effectiveFileName}, has bytes: ${p.hasBytes}');
        if (!p.hasBytes) {
          throw Exception('Shelf photo missing bytes data');
        }
      }
      for (var p in _additionalPhotos) {
        debugPrint('  Additional photo: ${p.effectiveFileName}, has bytes: ${p.hasBytes}');
        if (!p.hasBytes) {
          throw Exception('Additional photo missing bytes data');
        }
      }

      // Get API visit ID - prefer explicit apiVisitId, fallback to parsing from visit.id
      debugPrint('Initial visitId from widget.apiVisitId: $visitId');

      if (visitId == null) {
        // Try to extract from visit.id if it's in format "api-visit-{id}"
        final match = RegExp(r'api-visit-(\d+)').firstMatch(widget.visit.id);
        if (match != null) {
          visitId = int.tryParse(match.group(1)!);
          debugPrint('Extracted visitId from api-visit format: $visitId');
        } else {
          // Try direct parsing as fallback
          visitId = int.tryParse(widget.visit.id);
          debugPrint('Tried direct parsing of visit.id: $visitId');
        }
      }

      if (visitId == null) {
        debugPrint('ERROR: visitId is still null after all attempts');
        throw Exception('Aucune visite API active. Veuillez démarrer une visite depuis la fiche client.');
      }

      debugPrint('Final visitId for API: $visitId');
      debugPrint('Submitting report to API...');

      // Submit to API with GeotaggedPhoto objects (works on both web and mobile)
      await _visitApiService.submitVisitReport(
        visitId: visitId,
        latitude: position.latitude,
        longitude: position.longitude,
        shelfPhotos: _shelfPhotos,
        additionalPhotos: _additionalPhotos,
        managerPresent: _gerantPresent,
        orderMade: _orderPlaced,
        needsOrder: _needsOrder,
        orderReference: _orderReferenceController.text.trim().isNotEmpty
            ? _orderReferenceController.text.trim()
            : null,
        orderEstimatedAmount: _orderPlaced == true && _orderAmountController.text.trim().isNotEmpty
            ? double.tryParse(_orderAmountController.text.trim())
            : null,
        stockShortageObserved: _selectedStockShortages.isNotEmpty,
        stockIssues: stockShortagesText,
        competitorActivityObserved: _selectedCompetitorActivities.isNotEmpty,
        competitorActivity: competitorActivityText,
        comments: _commentsController.text.trim().isNotEmpty
            ? _commentsController.text.trim()
            : null,
      );

      // Create the local report object for backwards compatibility
      final report = _buildLocalReport(position, stockShortagesText, competitorActivityText);

      // Retourner le rapport validé
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rapport soumis avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(report);
      }
    } on VisitApiException catch (e) {
      debugPrint('=== VisitApiException caught ===');
      debugPrint('Message: ${e.message}');
      debugPrint('Status code: ${e.statusCode}');
      debugPrint('Error key: ${e.errorKey}');
      debugPrint('Errors: ${e.errors}');
      if (!kIsWeb &&
          visitId != null &&
          position != null &&
          OfflineQueueService.isNetworkError(e)) {
        await _queueReportOffline(
            visitId, position, stockShortagesText, competitorActivityText);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== Generic exception caught ===');
      debugPrint('Exception type: ${e.runtimeType}');
      debugPrint('Exception: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!kIsWeb &&
          visitId != null &&
          position != null &&
          OfflineQueueService.isNetworkError(e)) {
        await _queueReportOffline(
            visitId, position, stockShortagesText, competitorActivityText);
        return;
      }
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

  /// Construit l'objet rapport local (compatibilité avec le flux existant).
  VisitReport _buildLocalReport(
    Position position,
    String? stockShortagesText,
    String? competitorActivityText,
  ) {
    return VisitReport(
      id: widget.existingReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      visitId: widget.visit.id,
      clientId: widget.visit.clientId,
      clientName: widget.visit.clientName,
      startTime: widget.visit.actualStartTime ?? DateTime.now(),
      endTime: DateTime.now(),
      validationLatitude: position.latitude,
      validationLongitude: position.longitude,
      validationTime: DateTime.now(),
      shelfPhotos: _shelfPhotos,
      additionalPhotos: _additionalPhotos,
      gerantPresent: _gerantPresent,
      orderPlaced: _orderPlaced,
      needsOrder: _needsOrder,
      orderAmount: _orderPlaced == true && _orderAmountController.text.trim().isNotEmpty
          ? double.tryParse(_orderAmountController.text.trim())
          : null,
      orderReference: _orderReferenceController.text.trim().isNotEmpty
          ? _orderReferenceController.text.trim()
          : null,
      stockShortageObserved: _selectedStockShortages.isNotEmpty,
      stockShortages: stockShortagesText,
      competitorActivityObserved: _selectedCompetitorActivities.isNotEmpty,
      competitorActivity: competitorActivityText,
      comments: _commentsController.text.trim().isNotEmpty
          ? _commentsController.text.trim()
          : null,
      status: VisitReportStatus.validated,
      createdAt: widget.existingReport?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Mode hors ligne : le rapport (photos comprises) est enregistré localement
  /// et sera envoyé automatiquement au retour du réseau.
  Future<void> _queueReportOffline(
    int visitId,
    Position position,
    String? stockShortagesText,
    String? competitorActivityText,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/offline_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // Les photos sont copiées dans le stockage de l'app : les fichiers
    // temporaires de la caméra peuvent être purgés avant la synchronisation.
    final files = <Map<String, String>>[];
    Future<void> savePhotos(List<GeotaggedPhoto> photos, String field) async {
      for (final photo in photos) {
        final bytes = photo.bytes;
        if (bytes == null) continue;
        final filePath =
            '${photosDir.path}/${DateTime.now().microsecondsSinceEpoch}_${photo.effectiveFileName}';
        await File(filePath).writeAsBytes(bytes);
        files.add({'field': field, 'path': filePath});
      }
    }

    await savePhotos(_shelfPhotos, 'photo_shelves[]');
    await savePhotos(_additionalPhotos, 'photos_other[]');

    final fields = <String, String>{
      'visit_id': visitId.toString(),
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      if (_gerantPresent != null) 'manager_present': _gerantPresent! ? '1' : '0',
      if (_orderPlaced != null) 'order_made': _orderPlaced! ? '1' : '0',
      if (_needsOrder != null) 'needs_order': _needsOrder! ? '1' : '0',
      'stock_shortage_observed': _selectedStockShortages.isNotEmpty ? '1' : '0',
      'competitor_activity_observed':
          _selectedCompetitorActivities.isNotEmpty ? '1' : '0',
      if (_orderReferenceController.text.trim().isNotEmpty)
        'order_reference': _orderReferenceController.text.trim(),
      if (_orderPlaced == true && _orderAmountController.text.trim().isNotEmpty)
        'order_estimated_amount': _orderAmountController.text.trim(),
      if (stockShortagesText != null && stockShortagesText.isNotEmpty)
        'stock_issues': stockShortagesText,
      if (competitorActivityText != null && competitorActivityText.isNotEmpty)
        'competitor_activity': competitorActivityText,
      if (_commentsController.text.trim().isNotEmpty)
        'comments': _commentsController.text.trim(),
    };

    await OfflineQueueService().enqueue(OfflineOperation.multipart(
      label: 'Rapport de visite — ${widget.visit.clientName}',
      path: '/api/visits/$visitId/report',
      fields: fields,
      files: files,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pas de réseau : rapport enregistré localement. Il sera synchronisé automatiquement au retour de la connexion.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop(
          _buildLocalReport(position, stockShortagesText, competitorActivityText));
    }
  }

  Future<void> _createOrder() async {
    // Create a temporary client object from visit information
    final client = Client.legacy(
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

    // Navigate to order creation page with API integration
    final orderData = await Navigator.push<CreateOrderData>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderPage(
          preselectedClient: client,
          visitId: widget.apiVisitId,
        ),
      ),
    );

    if (orderData != null && mounted) {
      // Update order reference and amount from API response
      setState(() {
        _orderReferenceController.text = orderData.reference ?? 'CMD-${orderData.id}';
        _orderAmountController.text = orderData.totalAmount.toStringAsFixed(0);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande créée: ${orderData.totalAmount.toStringAsFixed(0)} ${orderData.currency}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SessionAwareAppBar(
        title: 'Rapport de Visite',
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

            // Photos rayons (multiple)
            _buildMultiPhotoSection(
              title: 'Photos Rayons / Linéaires',
              photos: _shelfPhotos,
              type: PhotoType.shelf,
              required: true,
              subtitle: 'Présentoirs et produits',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiPhotoSection({
    required String title,
    required List<GeotaggedPhoto> photos,
    required PhotoType type,
    required bool required,
    String? subtitle,
  }) {
    final bool hasPhotos = photos.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasPhotos ? Colors.green : (required ? Colors.orange : Colors.grey),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: hasPhotos ? Colors.green.withValues(alpha: 0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (required)
                          const Text(
                            ' *',
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        if (photos.isNotEmpty)
                          Text(
                            ' (${photos.length})',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null)
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
              if (hasPhotos)
                Icon(Icons.check_circle, color: Colors.green[600], size: 24),
            ],
          ),
          const SizedBox(height: 12),

          // Display existing photos in a grid
          if (photos.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: photo.hasBytes
                          ? Image.memory(
                              photo.bytes!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, size: 48),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(type, index: index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          // Add photo button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _capturePhoto(type),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: Text(photos.isEmpty ? 'Prendre une photo' : 'Ajouter une photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
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
        color: hasPhoto ? Colors.green.withValues(alpha: 0.05) : null,
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
              child: photo.hasBytes
                  ? Image.memory(
                      photo.bytes!,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 100,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 48),
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

            // Client a besoin d'une commande (si aucune commande réalisée)
            if (_orderPlaced == false) ...[
              CheckboxListTile(
                title: const Text(
                  'Le client a besoin d\'une commande',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Le client souhaite passer commande ultérieurement',
                  style: TextStyle(fontSize: 12),
                ),
                value: _needsOrder ?? false,
                onChanged: (value) => setState(() => _needsOrder = value),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.blue,
              ),
              const SizedBox(height: 16),
            ],

            // Ruptures observées
            const Text(
              'Ruptures observées (optionnel)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stockShortageOptions.map((option) {
                final isSelected = _selectedStockShortages.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedStockShortages.add(option);
                      } else {
                        _selectedStockShortages.remove(option);
                      }
                    });
                  },
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  checkmarkColor: Colors.blue,
                );
              }).toList(),
            ),
            // Text area for "Autre" option
            if (_selectedStockShortages.contains('Autre')) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockShortagesOtherController,
                decoration: const InputDecoration(
                  labelText: 'Précisez les autres ruptures',
                  hintText: 'Détaillez les produits en rupture...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 16),

            // Activité concurrente
            const Text(
              'Activité concurrente (optionnel)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _competitorActivityOptions.map((option) {
                final isSelected = _selectedCompetitorActivities.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCompetitorActivities.add(option);
                      } else {
                        _selectedCompetitorActivities.remove(option);
                      }
                    });
                  },
                  selectedColor: Colors.orange.withValues(alpha: 0.3),
                  checkmarkColor: Colors.orange,
                );
              }).toList(),
            ),
            // Text area for "Autre" option
            if (_selectedCompetitorActivities.contains('Autre')) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _competitorActivityOtherController,
                decoration: const InputDecoration(
                  labelText: 'Précisez l\'activité concurrente',
                  hintText: 'Détaillez l\'activité observée...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 16),

            // Commentaires libres
            const Text(
              'Commentaires libres (optionnel)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentsController,
              decoration: const InputDecoration(
                hintText: 'Observations générales, remarques, suggestions...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Row(
      children: [
        // Draft button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'Brouillon',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Validate button
        Expanded(
          flex: 3,
          child: SizedBox(
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
                _isSubmitting ? 'En cours...' : 'Valider la visite',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveDraft() async {
    try {
      // Build stock shortages string
      String? stockShortagesText;
      if (_selectedStockShortages.isNotEmpty) {
        List<String> shortages = List.from(_selectedStockShortages);
        if (_selectedStockShortages.contains('Autre') && _stockShortagesOtherController.text.trim().isNotEmpty) {
          shortages.remove('Autre');
          shortages.add(_stockShortagesOtherController.text.trim());
        }
        stockShortagesText = shortages.join(', ');
      }

      // Build competitor activity string
      String? competitorActivityText;
      if (_selectedCompetitorActivities.isNotEmpty) {
        List<String> activities = List.from(_selectedCompetitorActivities);
        if (_selectedCompetitorActivities.contains('Autre') && _competitorActivityOtherController.text.trim().isNotEmpty) {
          activities.remove('Autre');
          activities.add(_competitorActivityOtherController.text.trim());
        }
        competitorActivityText = activities.join(', ');
      }

      // Créer le rapport en brouillon
      final report = VisitReport(
        id: widget.existingReport?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        visitId: widget.visit.id,
        clientId: widget.visit.clientId,
        clientName: widget.visit.clientName,
        startTime: widget.visit.actualStartTime ?? DateTime.now(),
        endTime: DateTime.now(),
        validationLatitude: null,
        validationLongitude: null,
        validationTime: null,
        shelfPhotos: _shelfPhotos,
        additionalPhotos: _additionalPhotos,
        gerantPresent: _gerantPresent,
        orderPlaced: _orderPlaced,
        needsOrder: _needsOrder,
        orderAmount: _orderPlaced == true && _orderAmountController.text.trim().isNotEmpty
            ? double.tryParse(_orderAmountController.text.trim())
            : null,
        orderReference: _orderReferenceController.text.trim().isNotEmpty
            ? _orderReferenceController.text.trim()
            : null,
        stockShortageObserved: _selectedStockShortages.isNotEmpty,
        stockShortages: stockShortagesText,
        competitorActivityObserved: _selectedCompetitorActivities.isNotEmpty,
        competitorActivity: competitorActivityText,
        comments: _commentsController.text.trim().isNotEmpty
            ? _commentsController.text.trim()
            : null,
        status: VisitReportStatus.incomplete,
        createdAt: widget.existingReport?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Retourner le brouillon
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brouillon enregistré'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(report);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
