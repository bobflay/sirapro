import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sirapro/utils/phone_formatter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/models/client_photo.dart';
import 'package:sirapro/models/api_alert.dart';
import 'package:sirapro/services/alert_api_service.dart';
import 'package:sirapro/models/update_client_request.dart';
import 'package:sirapro/models/api_visit.dart';
import 'package:sirapro/models/start_visit_request.dart';
import 'package:sirapro/models/terminate_visit_request.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import '../constants.dart';
import '../models/visit.dart';
import '../models/visit_report.dart';
import '../services/api_service.dart';
import '../services/client_service.dart';
import '../services/visit_service.dart';
import '../services/visit_api_service.dart';
import '../services/offline_queue_service.dart';
import '../services/order_service.dart';
import '../models/order_api.dart';
import 'create_return_voucher_page.dart';
import 'return_voucher_detail_page.dart';
import '../models/return_voucher.dart';
import '../services/return_voucher_service.dart';
import '../widgets/session_aware_app_bar.dart';
import 'visit_report_page.dart';
import 'visit_report_detail_page.dart';
import 'create_order_page.dart';
import 'alert_creation_page.dart';
import 'alert_detail_page.dart';
import 'api_order_detail_page.dart';

class ClientDetailPage extends StatefulWidget {
  final Client client;

  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  static const String _baseUrl = 'https://sira.xpertbot.online';

  late Client _client;
  bool _isEditing = false;
  bool _isSaving = false;

  // Services
  final ClientService _clientService = ClientService();
  final VisitService _visitService = VisitService();
  final VisitApiService _visitApiService = VisitApiService();
  final OrderService _orderService = OrderService();
  final AlertApiService _alertApiService = AlertApiService();
  bool _isLoadingVisit = false;

  // Client photos - local files (newly added)
  // Store bytes for cross-platform compatibility (works on both web and mobile)
  final List<Uint8List> _localPhotoBytes = [];
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;
  final ImagePicker _imagePicker = ImagePicker();

  // Total photos count (API photos + local photos)
  int get _totalPhotosCount => _client.photos.length + _localPhotoBytes.length;

  // Visit tracking
  bool _isVisitActive = false;
  DateTime? _visitStartTime;
  Duration _visitDuration = Duration.zero;
  Timer? _visitTimer;
  bool _visitWasCompleted = false; // Track if visit was completed/terminated

  // Form controllers
  late TextEditingController _boutiqueNameController;
  late TextEditingController _gerantNameController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _quartierController;
  late TextEditingController _villeController;

  String? _selectedType;
  String? _selectedClientType;
  String? _selectedZone;
  String? _selectedPotentiel;
  String? _selectedFrequence;
  String? _selectedVisitDay;

  final _formKey = GlobalKey<FormState>();

  // GPS Location state for editing
  LatLng? _updatedGpsPosition;
  bool _isCapturingGps = false;
  static const double _maxAdjustmentRadius = 300.0;

  final List<String> _types = [
    'Boutique',
    'Supermarché',
    'Demi-grossiste',
    'Grossiste',
    'Distributeur',
    'Mamie marché',
    'Étalage',
    'Boulangerie',
    'Autre',
  ];

  final List<String> _clientTypes = [
    'Aucun',
    'B2B',
    'B2C',
  ];

  final List<String> _zones = [
    'Abidjan - Cocody',
    'Abidjan - Plateau',
    'Abidjan - Yopougon',
    'Abidjan - Abobo',
    'Abidjan - Adjamé',
    'Abidjan - Marcory',
    'Abidjan - Treichville',
    'Abidjan - Koumassi',
    'Abidjan - Port-Bouët',
    'Bouaké - Centre',
    'Yamoussoukro',
    'San-Pédro',
    'Daloa',
    'Korhogo',
    'Autre',
  ];

  final List<String> _potentiels = ['A', 'B', 'C'];

  final List<String> _frequences = [
    'Hebdomadaire',
    'Bimensuelle',
    'Mensuelle',
    'Autre',
  ];

  final List<String> _visitDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _initControllers();
    _loadActiveVisit();
  }

  /// Load any active visit from storage and sync state
  Future<void> _loadActiveVisit() async {
    await _visitService.loadActiveVisit();

    // Check if this client has an active visit
    if (_visitService.isClientVisitActive(_client.id)) {
      final activeVisit = _visitService.activeApiVisit;
      if (activeVisit != null) {
        setState(() {
          _isVisitActive = true;
          _visitStartTime = activeVisit.startedAt;
          if (_visitStartTime != null) {
            _visitDuration = DateTime.now().difference(_visitStartTime!);
          }
        });

        // Start the timer to update duration
        _visitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_visitStartTime != null) {
            setState(() {
              _visitDuration = DateTime.now().difference(_visitStartTime!);
            });
          }
        });
      }
    }
  }

  void _initControllers() {
    _boutiqueNameController = TextEditingController(text: _client.boutiqueName);
    _gerantNameController = TextEditingController(text: _client.gerantName);
    _phoneController = TextEditingController(text: _client.phone);
    _whatsappController = TextEditingController(text: _client.whatsapp ?? '');
    _emailController = TextEditingController(text: _client.email ?? '');
    _addressController = TextEditingController(text: _client.address);
    _quartierController = TextEditingController(text: _client.quartier);
    _villeController = TextEditingController(text: _client.ville);

    _selectedType = _client.type;
    _selectedClientType = _client.clientType ?? 'Aucun';
    _selectedZone = _client.zone;
    _selectedPotentiel = _client.potentiel;
    // Convert API value (english) to French label for dropdown
    _selectedFrequence = _client.visitFrequency != null
        ? UpdateClientRequest.apiValueToFrequency(_client.visitFrequency!)
        : null;
    _selectedVisitDay = UpdateClientRequest.apiValueToDay(_client.visitDay);
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    _photoPageController.dispose();
    _boutiqueNameController.dispose();
    _gerantNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _quartierController.dispose();
    _villeController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ajouter une photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Read bytes for cross-platform support
        final Uint8List bytes = await pickedFile.readAsBytes();

        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Téléchargement en cours...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        // Get current location for the photo
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        } catch (e) {
          // Location not available, continue without it
        }

        // Generate a proper filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = pickedFile.name.contains('.')
            ? pickedFile.name.split('.').last
            : 'jpg';
        final fileName = 'client_${_client.id}_$timestamp.$extension';

        // Create GeotaggedPhoto for cross-platform upload
        final geotaggedPhoto = GeotaggedPhoto(
          path: kIsWeb ? fileName : pickedFile.path,
          timestamp: DateTime.now(),
          bytes: bytes,
          fileName: fileName,
          latitude: position?.latitude,
          longitude: position?.longitude,
          mimeType: 'image/$extension',
        );

        // Upload using cross-platform method
        await _clientService.uploadGeotaggedPhotos(
          _client.id,
          [geotaggedPhoto],
          type: 'facade',
          title: 'Façade',
          description: 'Photo façade de ${_client.boutiqueName}',
        );

        // Hide loading snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        // Add to local list (store bytes for cross-platform display)
        setState(() {
          _localPhotoBytes.add(bytes);
          _currentPhotoIndex = _localPhotoBytes.length - 1;
        });

        // Animate to the new photo
        final totalLocalPhotos = _localPhotoBytes.length;
        if (totalLocalPhotos > 1) {
          _photoPageController.animateToPage(
            _currentPhotoIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo téléchargée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deletePhoto(int index) {
    final apiPhotosCount = _client.photos.length;
    final isApiPhoto = index < apiPhotosCount;

    // For now, only allow deleting local photos
    // API photos would need a DELETE API call
    if (isApiPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La suppression des photos synchronisées n\'est pas encore disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Voulez-vous vraiment supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final localIndex = index - apiPhotosCount;
              setState(() {
                _localPhotoBytes.removeAt(localIndex);
                if (_currentPhotoIndex >= _totalPhotosCount && _totalPhotosCount > 0) {
                  _currentPhotoIndex = _totalPhotosCount - 1;
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _viewPhotoFullScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoViewer(
          apiPhotos: _client.photos,
          localPhotoBytes: _localPhotoBytes,
          initialIndex: index,
          onDelete: _deletePhoto,
          baseUrl: _baseUrl,
        ),
      ),
    );
  }

  Future<void> _startVisit() async {
    // Check if already loading
    if (_isLoadingVisit) return;

    // Check if there's already an active visit (for any client)
    if (_visitService.hasActiveVisit) {
      final activeClientName = _visitService.activeClientName ?? 'un autre client';
      _showLocationError(
        'Visite en cours',
        'Vous avez déjà une visite en cours chez $activeClientName. Veuillez la terminer avant d\'en démarrer une nouvelle.',
      );
      return;
    }

    setState(() {
      _isLoadingVisit = true;
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Vérification de votre position...'),
          ],
        ),
      ),
    );

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) Navigator.pop(context);
        setState(() => _isLoadingVisit = false);
        _showLocationError(
          'Services de localisation désactivés',
          'Veuillez activer les services de localisation pour démarrer la visite.',
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) Navigator.pop(context);
          setState(() => _isLoadingVisit = false);
          _showLocationError(
            'Permission refusée',
            'La permission de localisation est nécessaire pour démarrer la visite.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context);
        setState(() => _isLoadingVisit = false);
        _showLocationError(
          'Permission refusée définitivement',
          'Veuillez activer la permission de localisation dans les paramètres de l\'application.',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) Navigator.pop(context);

      // Call the API to start the visit
      await _callStartVisitApi(position);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      _showLocationError(
        'Erreur de localisation',
        'Impossible d\'obtenir votre position. Veuillez réessayer.',
      );
    }
  }

  /// Call the API to start a visit
  Future<void> _callStartVisitApi(Position position) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Démarrage de la visite...'),
          ],
        ),
      ),
    );

    final request = StartVisitRequest(
      clientId: _client.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    try {
      final visit = await _visitApiService.startVisit(request);

      // Save to local storage with client for quick navigation
      await _visitService.startApiVisit(visit, client: _client);

      if (mounted) Navigator.pop(context);

      // Start the visit timer
      _startVisitTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visite démarrée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on VisitApiException catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);

      if (e.isProximityError) {
        _showProximityError(e);
      } else if (e.hasActiveVisit) {
        _showLocationError(
          'Visite en cours',
          e.message,
        );
      } else if (e.isInvalidClient) {
        _showLocationError(
          'Client invalide',
          e.message,
        );
      } else if (e.isUnauthorized) {
        _showLocationError(
          'Non autorisé',
          'Vous n\'êtes pas autorisé à visiter ce client.',
        );
      } else if (OfflineQueueService.isNetworkError(e)) {
        await _startVisitOffline(position, request);
      } else {
        _showLocationError(
          'Erreur',
          e.message,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      if (OfflineQueueService.isNetworkError(e)) {
        await _startVisitOffline(position, request);
        return;
      }
      _showLocationError(
        'Erreur',
        'Une erreur inattendue s\'est produite: $e',
      );
    }
  }

  /// Mode hors ligne : la visite démarre localement après un contrôle de
  /// proximité fait sur le téléphone (même règle que le serveur), puis le
  /// démarrage est rejoué au retour du réseau. La fin de visite et le rapport
  /// retrouveront l'id serveur via la référence {ref:visit_...}.
  Future<void> _startVisitOffline(
    Position position,
    StartVisitRequest request,
  ) async {
    if (_client.latitude != null && _client.longitude != null) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _client.latitude!,
        _client.longitude!,
      );
      if (distance > kVisitProximityThresholdMeters) {
        _showLocationError(
          'Trop loin du client',
          'Vous êtes à ${distance.toStringAsFixed(0)} m du point de vente '
          '(maximum ${kVisitProximityThresholdMeters.toStringAsFixed(0)} m). '
          'Rapprochez-vous pour démarrer la visite.',
        );
        return;
      }
    }

    final startedAt = DateTime.now();
    // Id local négatif : jamais confondu avec un id serveur.
    final localId = -startedAt.millisecondsSinceEpoch;

    await OfflineQueueService().enqueue(OfflineOperation.json(
      label: 'Début de visite — ${_client.name}',
      method: 'POST',
      path: '/api/visits',
      body: {
        ...request.toJson(),
        'started_at': startedAt.toIso8601String(),
      },
      provides: 'visit_$localId',
    ));

    final localVisit = ApiVisit(
      id: localId,
      clientId: _client.id,
      userId: 0,
      status: 'started',
      startedAt: startedAt,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    await _visitService.startApiVisit(localVisit, client: _client);

    _startVisitTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pas de réseau : visite démarrée hors ligne. Elle sera synchronisée automatiquement au retour de la connexion.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Show proximity error with distance information
  void _showProximityError(VisitApiException e) {
    final distanceInfo = e.proximityDetails ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Position trop éloignée', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message),
            if (distanceInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.straighten, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        distanceInfo,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Distance maximale autorisée: 15 mètres',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openGoogleMaps();
            },
            child: const Text('Voir sur la carte'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startVisitTimer() {
    setState(() {
      _isVisitActive = true;
      _isLoadingVisit = false;
      // Use the visit start time from API if available
      if (_visitStartTime == null) {
        _visitStartTime = DateTime.now();
      }
      _visitDuration = DateTime.now().difference(_visitStartTime!);
    });

    // Update the timer every second
    _visitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_visitStartTime != null) {
        setState(() {
          _visitDuration = DateTime.now().difference(_visitStartTime!);
        });
      }
    });
  }

  /// Show dialog to choose between completing or aborting the visit
  void _stopVisit() {
    final hours = _visitDuration.inHours;
    final minutes = _visitDuration.inMinutes % 60;
    final seconds = _visitDuration.inSeconds % 60;
    final durationText = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}min'
        : minutes > 0
            ? '${minutes}min ${seconds.toString().padLeft(2, '0')}s'
            : '${seconds}s';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header with icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryVeryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Terminer la visite',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),

            // Client name
            Text(
              _client.name,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkGray,
              ),
            ),
            const SizedBox(height: 16),

            // Duration chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryVeryLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: AppColors.secondaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Durée: $durationText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question
            Text(
              'Comment souhaitez-vous terminer cette visite?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Abort button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _terminateVisit('aborted');
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const Text('Abandonner'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Complete button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _terminateVisit('completed');
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Compléter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gray,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Terminate the visit with the given status
  Future<void> _terminateVisit(String status) async {
    // Check if we have an active visit ID
    final visitId = _visitService.activeVisitId;
    if (visitId == null) {
      // No API visit, just stop the timer locally
      _stopVisitLocally(status == 'completed');
      return;
    }

    setState(() {
      _isLoadingVisit = true;
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Vérification de votre position...'),
          ],
        ),
      ),
    );

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) Navigator.pop(context);
        setState(() => _isLoadingVisit = false);
        _showLocationError(
          'Services de localisation désactivés',
          'Veuillez activer les services de localisation pour terminer la visite.',
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) Navigator.pop(context);
          setState(() => _isLoadingVisit = false);
          _showLocationError(
            'Permission refusée',
            'La permission de localisation est nécessaire pour terminer la visite.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context);
        setState(() => _isLoadingVisit = false);
        _showLocationError(
          'Permission refusée définitivement',
          'Veuillez activer la permission de localisation dans les paramètres de l\'application.',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) Navigator.pop(context);

      // Call the API to terminate the visit
      await _callTerminateVisitApi(visitId, status, position);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      _showLocationError(
        'Erreur de localisation',
        'Impossible d\'obtenir votre position. Veuillez réessayer.',
      );
    }
  }

  /// Mode hors ligne : la fin de visite est enregistrée localement et sera
  /// rejouée automatiquement au retour du réseau. Une visite démarrée hors
  /// ligne (id local négatif) est référencée via {ref:visit_...}, résolu à la
  /// synchronisation ; l'heure de fin réelle est transmise au serveur.
  Future<void> _queueTerminateOffline(
    int visitId,
    TerminateVisitRequest request,
    String status,
  ) async {
    final pathSegment = visitId < 0 ? '{ref:visit_$visitId}' : '$visitId';
    await OfflineQueueService().enqueue(OfflineOperation.json(
      label: 'Fin de visite — ${_client.name}',
      method: 'POST',
      path: '/api/visits/$pathSegment/terminate',
      body: {
        ...request.toJson(),
        'ended_at': DateTime.now().toIso8601String(),
      },
    ));

    // La visite est considérée terminée côté app.
    await _visitService.endApiVisit();
    _stopVisitLocally(status == 'completed');
    _visitWasCompleted = true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pas de réseau : fin de visite enregistrée localement. Elle sera synchronisée automatiquement au retour de la connexion.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Call the API to terminate the visit
  Future<void> _callTerminateVisitApi(int visitId, String status, Position position) async {
    // Visite démarrée hors ligne, pas encore synchronisée : ne pas appeler
    // l'API avec l'id local — tout passe par la file d'attente.
    if (visitId < 0) {
      final request = TerminateVisitRequest(
        status: status,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _queueTerminateOffline(visitId, request, status);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(status == 'completed'
                ? 'Finalisation de la visite...'
                : 'Abandon de la visite...'),
          ],
        ),
      ),
    );

    final request = TerminateVisitRequest(
      status: status,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    try {
      final result = await _visitApiService.terminateVisit(visitId, request);

      // Clear local storage
      await _visitService.endApiVisit();

      if (mounted) Navigator.pop(context);

      // Stop the timer and reset state
      _stopVisitLocally(status == 'completed');

      // Mark that visit was completed for proper navigation result
      _visitWasCompleted = true;

      if (mounted) {
        // Check if there's a warning (terminated outside allowed range)
        if (result.terminatedOutsideRange && result.warning != null) {
          _showOutsideRangeWarning(result.warning!, result.terminationDistance, status);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'completed'
                  ? 'Visite complétée avec succès'
                  : 'Visite abandonnée'),
              backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } on VisitApiException catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);

      if (OfflineQueueService.isNetworkError(e)) {
        await _queueTerminateOffline(visitId, request, status);
        return;
      }

      if (e.isReasonRequired) {
        // Distance exceeded - show reason selection dialog
        final reasonResult = await _showDistanceExceedReasonDialog(
          distance: e.distance ?? 0,
          maxDistance: e.maxAllowedDistance ?? 300,
          availableReasons: e.availableReasons ?? DistanceExceedReasons.reasons,
        );

        if (reasonResult != null && mounted) {
          // Retry with the reason
          await _callTerminateVisitApiWithReason(
            visitId,
            status,
            position,
            reasonResult.reason,
            reasonResult.otherText,
          );
        }
      } else if (e.isProximityError) {
        _showProximityError(e);
      } else if (e.isAlreadyTerminated) {
        // Visit was already terminated, clear local state
        await _visitService.endApiVisit();
        _stopVisitLocally(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La visite a déjà été terminée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (e.isUnauthorized) {
        _showLocationError(
          'Non autorisé',
          'Vous n\'êtes pas autorisé à terminer cette visite.',
        );
      } else if (e.isNotFound) {
        // Visit not found, clear local state
        await _visitService.endApiVisit();
        _stopVisitLocally(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La visite n\'existe plus'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        _showLocationError(
          'Erreur',
          e.message,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      if (OfflineQueueService.isNetworkError(e)) {
        await _queueTerminateOffline(visitId, request, status);
        return;
      }
      _showLocationError(
        'Erreur',
        'Une erreur inattendue s\'est produite: $e',
      );
    }
  }

  /// Call the API to terminate the visit with distance exceed reason
  Future<void> _callTerminateVisitApiWithReason(
    int visitId,
    String status,
    Position position,
    String reason,
    String? otherText,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(status == 'completed'
                ? 'Finalisation de la visite...'
                : 'Abandon de la visite...'),
          ],
        ),
      ),
    );

    final request = TerminateVisitRequest(
      status: status,
      latitude: position.latitude,
      longitude: position.longitude,
      distanceExceedReason: reason,
      distanceExceedReasonOther: otherText,
    );

    try {
      final result = await _visitApiService.terminateVisit(visitId, request);

      // Clear local storage
      await _visitService.endApiVisit();

      if (mounted) Navigator.pop(context);

      // Stop the timer and reset state
      _stopVisitLocally(status == 'completed');

      // Mark that visit was completed for proper navigation result
      _visitWasCompleted = true;

      if (mounted) {
        // Show success with warning about outside range
        if (result.terminatedOutsideRange && result.warning != null) {
          _showOutsideRangeWarning(result.warning!, result.terminationDistance, status);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'completed'
                  ? 'Visite complétée avec succès'
                  : 'Visite abandonnée'),
              backgroundColor: status == 'completed' ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } on VisitApiException catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      if (OfflineQueueService.isNetworkError(e)) {
        await _queueTerminateOffline(visitId, request, status);
        return;
      }
      _showLocationError('Erreur', e.message);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isLoadingVisit = false);
      if (OfflineQueueService.isNetworkError(e)) {
        await _queueTerminateOffline(visitId, request, status);
        return;
      }
      _showLocationError(
        'Erreur',
        'Une erreur inattendue s\'est produite: $e',
      );
    }
  }

  /// Show warning dialog when visit was terminated outside the allowed range
  void _showOutsideRangeWarning(String warning, double? distance, String status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status == 'completed' ? 'Visite complétée' : 'Visite abandonnée',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status == 'completed'
                  ? 'La visite a été complétée avec succès.'
                  : 'La visite a été abandonnée.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_off,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attention',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Visite terminée en dehors de la zone autorisée.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Distance: ${distance.toStringAsFixed(0)} mètres',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Distance maximale autorisée: 300 mètres',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to select reason for distance exceed
  /// Returns the selected reason key and optional other text, or null if cancelled
  Future<({String reason, String? otherText})?> _showDistanceExceedReasonDialog({
    required double distance,
    required double maxDistance,
    required Map<String, String> availableReasons,
  }) async {
    String? selectedReason;
    final otherTextController = TextEditingController();
    bool showOtherField = false;

    return showDialog<({String reason, String? otherText})>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Distance dépassée',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_off, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vous êtes à ${distance.toStringAsFixed(0)} mètres du client',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Distance maximale: ${maxDistance.toStringAsFixed(0)} mètres',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Veuillez indiquer la raison:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ...availableReasons.entries.map((entry) => RadioListTile<String>(
                  title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  value: entry.key,
                  groupValue: selectedReason,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedReason = value;
                      showOtherField = value == 'other';
                    });
                  },
                )),
                if (showOtherField) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherTextController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Précisez',
                      hintText: 'Entrez la raison...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                    maxLength: 500,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null ||
                      (selectedReason == 'other' && otherTextController.text.trim().isEmpty)
                  ? null
                  : () {
                      Navigator.pop(context, (
                        reason: selectedReason!,
                        otherText: selectedReason == 'other'
                            ? otherTextController.text.trim()
                            : null,
                      ));
                    },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Stop the visit timer locally without API call
  void _stopVisitLocally(bool completed) {
    _visitTimer?.cancel();

    final duration = _visitDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    String durationText;
    if (hours > 0) {
      durationText = '${hours}h ${minutes}min ${seconds}s';
    } else if (minutes > 0) {
      durationText = '${minutes}min ${seconds}s';
    } else {
      durationText = '${seconds}s';
    }

    setState(() {
      _isVisitActive = false;
      _isLoadingVisit = false;
      _visitTimer = null;
      _visitStartTime = null;
      _visitDuration = Duration.zero;
    });
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // Cancel editing - reset controllers and GPS position
        _initControllers();
        _updatedGpsPosition = null;
      }
      _isEditing = !_isEditing;
    });
  }

  /// Show location permission dialog when permanently denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Permission requise'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La permission de localisation a été refusée de manière permanente.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              'Pour activer la permission sur iOS :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Allez dans Réglages > Confidentialité et sécurité'),
            Text('2. Choisissez "Services de localisation"'),
            Text('3. Activez la permission pour SIRA PRO'),
            Text('4. Revenez à l\'application'),
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

  /// Show the location picker as a full screen page for adjusting GPS position
  Future<LatLng?> _showLocationPickerDialog(LatLng initialPosition) async {
    return Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => _LocationPickerPage(
          initialPosition: initialPosition,
          maxRadius: _maxAdjustmentRadius,
        ),
      ),
    );
  }

  /// Capture GPS position for updating client location
  Future<void> _captureGpsPosition() async {
    setState(() {
      _isCapturingGps = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La permission de localisation est requise.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isCapturingGps = false);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog();
        }
        setState(() => _isCapturingGps = false);
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez activer le service de localisation.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isCapturingGps = false);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final gpsPosition = LatLng(position.latitude, position.longitude);

      // Show map picker for fine-tuning
      if (mounted) {
        final adjustedPosition = await _showLocationPickerDialog(gpsPosition);
        if (adjustedPosition != null) {
          setState(() {
            _updatedGpsPosition = adjustedPosition;
            _isCapturingGps = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text('Position GPS mise à jour')),
                  ],
                ),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() => _isCapturingGps = false);
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
        setState(() => _isCapturingGps = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prevent double submission
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Mise à jour en cours...'),
          ],
        ),
      ),
    );

    // Build the update request with only changed fields
    final request = UpdateClientRequest(
      name: _boutiqueNameController.text.trim(),
      type: _selectedType,
      clientType: _selectedClientType == 'Aucun' ? null : _selectedClientType,
      managerName: _gerantNameController.text.trim(),
      phone: PhoneUtils.stripSpaces(_phoneController.text.trim()),
      whatsapp: _whatsappController.text.trim().isNotEmpty
          ? PhoneUtils.stripSpaces(_whatsappController.text.trim())
          : null,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      addressDescription: _addressController.text.trim(),
      district: _quartierController.text.trim().isNotEmpty
          ? _quartierController.text.trim()
          : null,
      city: _villeController.text.trim(),
      potential: _selectedPotentiel,
      visitFrequency: _selectedFrequence != null
          ? UpdateClientRequest.frequencyToApiValue(_selectedFrequence!)
          : null,
      visitDay: UpdateClientRequest.dayToApiValue(_selectedVisitDay),
      // Include GPS coordinates if updated
      latitude: _updatedGpsPosition?.latitude,
      longitude: _updatedGpsPosition?.longitude,
    );

    try {
      // Call the API to update the client
      final updatedClient = await _clientService.updateClient(_client.id, request);

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      // Update local state with the response from API
      setState(() {
        _client = updatedClient;
        _isEditing = false;
        _isSaving = false;
        _updatedGpsPosition = null; // Reset GPS position after successful save
      });

      // Reinitialize controllers with updated data
      _initControllers();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Client mis à jour avec succès'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      setState(() {
        _isSaving = false;
      });

      if (OfflineQueueService.isNetworkError(e)) {
        await _queueClientUpdateOffline(request);
        return;
      }

      // Handle specific error codes
      if (e.statusCode == 403) {
        _showErrorDialog(
          'Accès refusé',
          'Vous n\'avez pas la permission de modifier ce client.',
        );
      } else if (e.statusCode == 404) {
        _showErrorDialog(
          'Client introuvable',
          'Ce client n\'existe plus dans le système.',
        );
      } else if (e.statusCode == 422) {
        _showErrorDialog(
          'Erreur de validation',
          e.message,
        );
      } else {
        _showErrorSnackbar(e.message);
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      setState(() {
        _isSaving = false;
      });

      if (OfflineQueueService.isNetworkError(e)) {
        await _queueClientUpdateOffline(request);
        return;
      }

      _showErrorSnackbar('Une erreur inattendue s\'est produite: $e');
    }
  }

  /// Mode hors ligne : la mise à jour du PDV est enregistrée localement et
  /// rejouée automatiquement au retour du réseau. La fiche affiche
  /// immédiatement les nouvelles valeurs (application optimiste).
  Future<void> _queueClientUpdateOffline(UpdateClientRequest request) async {
    await OfflineQueueService().enqueue(OfflineOperation.json(
      label: 'Mise à jour client — ${_client.name}',
      method: 'PUT',
      path: '/api/clients/${_client.id}',
      body: request.toJson(),
    ));

    setState(() {
      _client = _client.copyWith(
        name: request.name,
        type: request.type,
        clientType: request.clientType,
        managerName: request.managerName,
        // Un téléphone vidé signifie « numéro non communiqué ».
        phones: (request.phone != null && request.phone!.isEmpty)
            ? <String>[]
            : null,
        phone: (request.phone?.isNotEmpty ?? false) ? request.phone : null,
        whatsapp: request.whatsapp,
        email: request.email,
        address: request.addressDescription,
        quartier: request.district,
        city: request.city,
        potential: request.potential,
        visitFrequency: request.visitFrequency,
        visitDay: request.visitDay,
        latitude: request.latitude,
        longitude: request.longitude,
      );
      _isEditing = false;
      _isSaving = false;
      _updatedGpsPosition = null;
    });
    _initControllers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pas de réseau : modifications enregistrées localement. Elles seront synchronisées automatiquement au retour de la connexion.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Clean the phone number (remove spaces, dashes, etc.)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri.parse('tel:$cleanNumber');

    try {
      await launchUrl(phoneUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de lancer l\'appel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Clean the phone number and ensure it has country code
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    // Remove leading + if present for WhatsApp URL
    if (cleanNumber.startsWith('+')) {
      cleanNumber = cleanNumber.substring(1);
    }
    // Add Ivory Coast country code if not present (225)
    if (!cleanNumber.startsWith('225') && cleanNumber.length <= 10) {
      cleanNumber = '225$cleanNumber';
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri.parse('mailto:$email');

    try {
      await launchUrl(emailUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMaps() async {
    // Check if client has GPS coordinates
    if (!_client.hasLocation) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune coordonnée GPS disponible pour ce client'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final lat = _client.latitude!;
    final lng = _client.longitude!;

    // Open Google Maps with just the GPS coordinates
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
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


  /// Parses GPS coordinates from format "5.3600° N, 4.0083° W" to LatLng
  /// Returns null if parsing fails
  LatLng? _parseGpsCoordinates(String? gpsLocation) {
    if (gpsLocation == null) return null;

    try {
      // Remove degree symbols and split by comma
      final parts = gpsLocation.split(',');
      if (parts.length != 2) return null;

      final latPart = parts[0].trim();
      final lngPart = parts[1].trim();

      // Parse latitude (e.g., "5.3600° N" or "5.3600 N")
      final latMatch = RegExp(r'([\d.]+)°?\s*([NS])?').firstMatch(latPart);
      if (latMatch == null) return null;
      double lat = double.parse(latMatch.group(1)!);
      if (latMatch.group(2) == 'S') lat = -lat;

      // Parse longitude (e.g., "4.0083° W" or "4.0083 W")
      final lngMatch = RegExp(r'([\d.]+)°?\s*([EW])?').firstMatch(lngPart);
      if (lngMatch == null) return null;
      double lng = double.parse(lngMatch.group(1)!);
      if (lngMatch.group(2) == 'W') lng = -lng;

      return LatLng(lat, lng);
    } catch (e) {
      return null;
    }
  }

  /// Returns LatLng for the client, using GPS coordinates if available
  /// or a default location for the city
  LatLng _getClientLocation() {
    // Try to parse GPS coordinates first
    final gpsLatLng = _parseGpsCoordinates(_client.gpsLocation);
    if (gpsLatLng != null) return gpsLatLng;

    // Default to Abidjan coordinates if no GPS
    return const LatLng(5.3600, -4.0083);
  }

  Widget _buildMapWidget() {
    final location = _getClientLocation();
    return GestureDetector(
      onTap: _openGoogleMaps,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: location,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(_client.id.toString()),
                  position: location,
                  infoWindow: InfoWindow(
                    title: _client.boutiqueName,
                    snippet: _client.fullAddress,
                  ),
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
              zoomGesturesEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
            // Overlay to capture taps
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // Tap indicator overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'Appuyez pour ouvrir',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _visitWasCompleted);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: SessionAwareAppBar(
          title: _isEditing ? 'Modifier Client' : 'Détails Client',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _visitWasCompleted),
          ),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _toggleEdit,
                tooltip: 'Modifier',
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleEdit,
                tooltip: 'Annuler',
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveChanges,
                tooltip: 'Enregistrer',
              ),
            ],
          ],
        ),
        body: _isEditing ? _buildEditMode() : _buildViewMode(),
      ),
    );
  }

  Widget _buildViewMode() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Section with Photo Slider
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Photo Slider or Default Icon
                SizedBox(
                  height: 200,
                  child: _totalPhotosCount == 0
                      ? _buildDefaultHeader()
                      : _buildPhotoSlider(),
                ),
                // Client Info - Compact 2 lines
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // Line 1: Name + Type
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _client.boutiqueName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _client.type,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Line 2: Status + Potentiel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_client.isActive ?? false) ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _client.status ?? 'Inconnu',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (_client.potentiel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPotentielColor(_client.potentiel!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Potentiel ${_client.potentiel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Visit Timer Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildVisitTimerSlider(),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.phone,
                    label: 'Appeler',
                    color: Colors.green,
                    onTap: _client.phone.isNotEmpty
                        ? () => _makePhoneCall(_client.phone)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: (_client.whatsapp?.isNotEmpty ?? false) || _client.phone.isNotEmpty
                        ? () => _openWhatsApp(_client.whatsapp?.isNotEmpty == true ? _client.whatsapp! : _client.phone)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.blue,
                    onTap: (_client.email?.isNotEmpty ?? false)
                        ? () => _sendEmail(_client.email!)
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Client Status Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Statut du client'),
                const SizedBox(height: 12),
                _buildStatusCard(),
              ],
            ),
          ),

          // Quick Actions Section (hidden for Fermé or Suspendu clients)
          if (_client.status != 'Fermé' && _client.status != 'Suspendu') ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Actions rapides'),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Information Sections
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Information
                _buildSectionTitle('Informations de contact'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow(Icons.person, 'Gérant', _client.gerantName),
                  _buildInfoRow(Icons.phone, 'Téléphone', _client.phone),
                  if (_client.whatsapp != null)
                    _buildInfoRow(Icons.chat, 'WhatsApp', _client.whatsapp!),
                  if (_client.email != null)
                    _buildInfoRow(Icons.email, 'Email', _client.email!),
                ]),

                const SizedBox(height: 20),

                // Location Information
                _buildSectionTitle('Localisation'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow(Icons.location_on, 'Adresse', _client.address),
                  _buildInfoRow(Icons.map, 'Quartier', _client.quartier ?? ''),
                  _buildInfoRow(Icons.location_city, 'Ville', _client.ville),
                  if (_client.zone != null)
                    _buildInfoRow(Icons.grid_view, 'Zone', _client.zone!),
                  if (_client.gpsLocation != null)
                    _buildInfoRow(Icons.gps_fixed, 'GPS', _client.gpsLocation!),
                ]),
                const SizedBox(height: 12),
                // Google Maps Widget
                _buildMapWidget(),
                const SizedBox(height: 12),
                // Google Maps Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Voir sur Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Commercial Information
                _buildSectionTitle('Informations commerciales'),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _buildInfoRow(Icons.category, 'Type', _client.type),
                  if (_client.clientType != null && _client.clientType!.isNotEmpty)
                    _buildInfoRow(Icons.business, 'Classification', _client.clientType!),
                  if (_client.potentiel != null)
                    _buildInfoRow(Icons.star, 'Potentiel', _client.potentiel!),
                  if (_client.frequenceVisite != null)
                    _buildInfoRow(
                      Icons.schedule,
                      'Fréquence de visite',
                      _client.frequenceVisite!,
                    ),
                  if (_client.visitDay != null)
                    _buildInfoRow(
                      Icons.today,
                      'Jour de visite',
                      UpdateClientRequest.apiValueToDay(_client.visitDay) ?? _client.visitDay!,
                    ),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Client depuis',
                    _formatDate(_client.createdAt),
                  ),
                ]),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Administrative Data
            _buildSectionTitle('Données administratives'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _boutiqueNameController,
              label: 'Nom de la boutique *',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nom de la boutique';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedType,
              label: 'Type *',
              items: _types,
              onChanged: (value) => setState(() => _selectedType = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedClientType,
              label: 'Classification (B2B/B2C)',
              items: _clientTypes,
              onChanged: (value) => setState(() => _selectedClientType = value),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _gerantNameController,
              label: 'Nom du gérant *',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le nom du gérant';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Téléphone',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone,
              hintText: '05 XX XX XX XX (facultatif)',
              inputFormatters: [PhoneNumberFormatter()],
              validator: (value) {
                return PhoneUtils.validateOptional(value ?? '');
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.chat,
              hintText: '05 XX XX XX XX',
              inputFormatters: [PhoneNumberFormatter()],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email,
            ),

            const SizedBox(height: 24),

            // Geographic Data
            _buildSectionTitle('Données géographiques'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Adresse *',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer l\'adresse';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _quartierController,
              label: 'Quartier *',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le quartier';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _villeController,
              label: 'Ville *',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer la ville';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedZone,
              label: 'Zone / Secteur',
              items: _zones,
              onChanged: (value) => setState(() => _selectedZone = value),
            ),
            const SizedBox(height: 16),
            // GPS Position capture button
            _buildGpsCaptureButton(),

            const SizedBox(height: 24),

            // Commercial Data
            _buildSectionTitle('Données commerciales'),
            const SizedBox(height: 16),
            const Text(
              'Potentiel du client',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _potentiels.map((potentiel) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          potentiel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedPotentiel == potentiel
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                      selected: _selectedPotentiel == potentiel,
                      onSelected: (selected) {
                        setState(() {
                          _selectedPotentiel = selected ? potentiel : null;
                        });
                      },
                      selectedColor: _getPotentielColor(potentiel),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedFrequence,
              label: 'Fréquence de visite',
              items: _frequences,
              onChanged: (value) => setState(() => _selectedFrequence = value),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedVisitDay,
              label: 'Jour de visite',
              items: _visitDays,
              onChanged: (value) => setState(() => _selectedVisitDay = value),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Enregistrer les modifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: Icons.assignment,
                label: 'Rapport\nde visite',
                color: Colors.blue,
                onTap: _createVisitReport, // Always enabled to view reports
              ),
              _buildQuickActionButton(
                icon: Icons.shopping_cart,
                label: 'Commandes',
                color: Colors.green,
                onTap: _viewOrders, // Always enabled to view and create orders
              ),
              _buildQuickActionButton(
                icon: Icons.warning_amber,
                label: 'Alertes',
                color: Colors.orange,
                onTap: _viewAlerts, // Always enabled to view and create alerts
              ),
              _buildQuickActionButton(
                icon: Icons.assignment_return,
                label: 'Bon de\nRetour',
                color: AppColors.secondaryDark,
                onTap: _viewReturnVouchers,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return InkWell(
      onTap: isEnabled
          ? onTap
          : () {
              // Show message when trying to tap disabled button
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Veuillez démarrer la visite pour accéder à cette action'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            },
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createVisitReport() {
    // Show bottom sheet that fetches reports from API
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VisitReportsBottomSheet(
        clientId: _client.id,
        clientName: _client.boutiqueName,
        isVisitActive: _isVisitActive,
        visitApiService: _visitApiService,
        onNewReport: () {
          Navigator.pop(context);
          _navigateToNewVisitReport();
        },
        onViewReport: (report) => _viewVisitReportDetails(report),
      ),
    );
  }

  void _viewVisitReportDetails(VisitReport report) {
    Navigator.pop(context); // Close the bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisitReportDetailPage(report: report),
      ),
    );
  }

  Future<void> _navigateToNewVisitReport() async {
    final visitService = VisitService();

    // Check if there's an active visit for a DIFFERENT client
    if (visitService.hasActiveVisit && !visitService.isClientVisitActive(_client.id)) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Visite déjà en cours'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vous avez déjà une visite active en cours.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Client: ${visitService.activeClientName}'),
              const SizedBox(height: 8),
              const Text(
                'Veuillez terminer la visite en cours avant d\'en commencer une nouvelle.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // If the current client already has an active API visit, use it for the report
    if (visitService.isClientVisitActive(_client.id)) {
      final activeApiVisit = visitService.activeApiVisit;
      if (activeApiVisit != null) {
        // Create a Visit object from the active API visit
        final visit = Visit(
          id: 'api-visit-${activeApiVisit.id}',
          routeId: 'api-visit',
          clientId: _client.id.toString(),
          clientName: _client.boutiqueName,
          clientAddress: _client.fullAddress,
          order: 1,
          latitude: _parseLatitude(_client.gpsLocation),
          longitude: _parseLongitude(_client.gpsLocation),
          status: VisitStatus.inProgress,
          actualStartTime: activeApiVisit.startedAt ?? DateTime.now(),
          createdAt: activeApiVisit.startedAt ?? DateTime.now(),
        );

        if (!mounted) return;

        // Navigate to visit report page with the existing visit
        final VisitReport? report = await Navigator.push<VisitReport>(
          context,
          MaterialPageRoute(
            builder: (context) => VisitReportPage(
              visit: visit,
              existingReport: null,
              apiVisitId: activeApiVisit.id,
            ),
          ),
        );

        if (report != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rapport de visite créé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
    }

    // No active visit - create a new legacy visit for this specific client
    final visit = Visit(
      id: 'visit-${DateTime.now().millisecondsSinceEpoch}',
      routeId: 'ad-hoc-visit',
      clientId: _client.id.toString(),
      clientName: _client.boutiqueName,
      clientAddress: _client.fullAddress,
      order: 1,
      latitude: _parseLatitude(_client.gpsLocation),
      longitude: _parseLongitude(_client.gpsLocation),
      status: VisitStatus.inProgress,
      actualStartTime: DateTime.now(),
      createdAt: DateTime.now(),
    );

    // Enregistrer la visite comme active
    if (!visitService.startVisit(visit)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de démarrer la visite'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    // Navigate to visit report page
    final VisitReport? report = await Navigator.push<VisitReport>(
      context,
      MaterialPageRoute(
        builder: (context) => VisitReportPage(
          visit: visit,
          existingReport: null,
        ),
      ),
    );

    // Terminer la visite active quand on revient
    visitService.endVisit();

    if (report != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapport de visite créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  double? _parseLatitude(String? gpsLocation) {
    if (gpsLocation == null) return 5.3600; // Default Abidjan
    try {
      final coords = gpsLocation
          .replaceAll('°', '')
          .replaceAll(' N', '')
          .replaceAll(' S', '')
          .replaceAll(' E', '')
          .replaceAll(' W', '')
          .split(',');
      if (coords.isNotEmpty) {
        return double.tryParse(coords[0].trim());
      }
    } catch (e) {
      // Return default
    }
    return 5.3600;
  }

  double? _parseLongitude(String? gpsLocation) {
    if (gpsLocation == null) return -4.0083; // Default Abidjan
    try {
      final coords = gpsLocation
          .replaceAll('°', '')
          .replaceAll(' N', '')
          .replaceAll(' S', '')
          .replaceAll(' E', '')
          .replaceAll(' W', '')
          .split(',');
      if (coords.length > 1) {
        return double.tryParse(coords[1].trim());
      }
    } catch (e) {
      // Return default
    }
    return -4.0083;
  }

  Future<void> _createOrder() async {
    // Navigate to order creation page with API integration
    final orderData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderPage(
          preselectedClient: _client,
          visitId: _visitService.activeVisitId,
        ),
      ),
    );

    if (orderData != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande créée avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _viewOrders() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _OrdersBottomSheet(
        clientId: _client.id,
        orderService: _orderService,
        isVisitActive: _isVisitActive,
        onCreateOrder: () {
          Navigator.pop(context);
          _createOrder();
        },
      ),
    );
  }

  void _viewReturnVouchers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReturnVouchersBottomSheet(
        clientId: _client.id,
        clientName: _client.name,
        isVisitActive: _isVisitActive,
        onCreateReturnVoucher: () {
          Navigator.pop(context);
          _createNewReturnVoucher();
        },
      ),
    );
  }

  Future<void> _createNewReturnVoucher() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateReturnVoucherPage(
          preselectedClient: _client,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bon de retour créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _viewAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AlertsBottomSheet(
        clientId: _client.id,
        alertApiService: _alertApiService,
        isVisitActive: _isVisitActive,
        onCreateAlert: () {
          Navigator.pop(context);
          _createNewAlert();
        },
      ),
    );
  }

  Future<void> _createNewAlert() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertCreationPage(client: _client),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerte créée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: children,
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusOptions = ['Actif', 'Fermé', 'Refusé de commande', 'En attente', 'Suspendu'];
    final currentStatus = _client.status ?? 'Actif';

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: _getStatusColor(currentStatus),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Statut actuel: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                currentStatus,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(currentStatus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Changer le statut:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusOptions.map((status) {
              final isSelected = status == currentStatus;
              return InkWell(
                onTap: () => _updateClientStatus(status),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _getStatusColor(status).withValues(alpha: 0.1)
                        : Colors.grey[100],
                    border: Border.all(
                      color: isSelected
                          ? _getStatusColor(status)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 16,
                        color: isSelected
                            ? _getStatusColor(status)
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? _getStatusColor(status)
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Actif':
        return Colors.green;
      case 'Fermé':
        return Colors.red;
      case 'Refusé de commande':
        return Colors.deepOrange;
      case 'En attente':
        return Colors.orange;
      case 'Suspendu':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Actif':
        return Icons.check_circle;
      case 'Fermé':
        return Icons.cancel;
      case 'Refusé de commande':
        return Icons.block;
      case 'En attente':
        return Icons.pending;
      case 'Suspendu':
        return Icons.pause_circle;
      default:
        return Icons.info;
    }
  }

  Future<void> _updateClientStatus(String newStatus) async {
    if (newStatus == (_client.status ?? 'Actif')) {
      return; // No change needed
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le changement'),
        content: Text(
          'Voulez-vous vraiment changer le statut du client à "$newStatus"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updatedClient = await _clientService.updateClientStatus(
        _client.id,
        newStatus,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      setState(() {
        _client = updatedClient;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isEnabled ? color : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the GPS capture button for edit mode
  Widget _buildGpsCaptureButton() {
    final hasUpdatedPosition = _updatedGpsPosition != null;
    final hasExistingPosition = _client.hasLocation;

    // Determine what to show
    String currentLocationText;
    if (hasUpdatedPosition) {
      currentLocationText = '${_updatedGpsPosition!.latitude.toStringAsFixed(6)}, ${_updatedGpsPosition!.longitude.toStringAsFixed(6)}';
    } else if (hasExistingPosition) {
      currentLocationText = '${_client.latitude!.toStringAsFixed(6)}, ${_client.longitude!.toStringAsFixed(6)}';
    } else {
      currentLocationText = 'Non définie';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: hasUpdatedPosition
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.white,
        border: Border.all(
          color: hasUpdatedPosition
              ? AppColors.success
              : Colors.grey[300]!,
          width: hasUpdatedPosition ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCapturingGps ? null : _captureGpsPosition,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasUpdatedPosition
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _isCapturingGps
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              hasUpdatedPosition ? AppColors.success : AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          hasUpdatedPosition ? Icons.check_circle : Icons.my_location,
                          color: hasUpdatedPosition ? AppColors.success : AppColors.primary,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUpdatedPosition
                            ? 'Position GPS mise à jour'
                            : 'Mettre à jour la position GPS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasUpdatedPosition ? AppColors.success : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentLocationText,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUpdatedPosition
                              ? AppColors.success.withValues(alpha: 0.8)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasUpdatedPosition ? Icons.edit : Icons.chevron_right,
                  color: hasUpdatedPosition ? AppColors.success : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Supermarché':
        return Icons.store;
      case 'Grossiste':
        return Icons.warehouse;
      case 'Demi-grossiste':
        return Icons.inventory_2;
      case 'Distributeur':
        return Icons.local_shipping;
      default:
        return Icons.shopping_bag;
    }
  }

  Widget _buildDefaultHeader() {
    return Stack(
      children: [
        // Default icon background
        Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconForType(_client.type),
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
        // Add photo button
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _addPhoto,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ajouter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSlider() {
    final apiPhotosCount = _client.photos.length;

    return Stack(
      children: [
        // Photo PageView
        PageView.builder(
          controller: _photoPageController,
          onPageChanged: (index) {
            setState(() {
              _currentPhotoIndex = index;
            });
          },
          itemCount: _totalPhotosCount,
          itemBuilder: (context, index) {
            // First show API photos, then local photos
            final isApiPhoto = index < apiPhotosCount;
            final ImageProvider imageProvider;

            if (isApiPhoto) {
              final photo = _client.photos[index];
              final photoUrl = photo.getFullUrl(_baseUrl);
              imageProvider = NetworkImage(photoUrl);
            } else {
              final localIndex = index - apiPhotosCount;
              imageProvider = MemoryImage(_localPhotoBytes[localIndex]);
            }

            return GestureDetector(
              onTap: () => _viewPhotoFullScreen(index),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {},
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Theme.of(context).primaryColor.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Add photo button
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _addPhoto,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.add_a_photo,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        // Photo counter and dots
        if (_totalPhotosCount > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPhotosCount > 10 ? 10 : _totalPhotosCount, // Limit dots to 10
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPhotoIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        // Photo count badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_currentPhotoIndex + 1}/$_totalPhotosCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getPotentielColor(String potentiel) {
    switch (potentiel) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.orange;
      case 'C':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVisitTimerSlider() {
    if (_isVisitActive) {
      // Active visit - show timer and stop slider
      final hours = _visitDuration.inHours;
      final minutes = _visitDuration.inMinutes % 60;
      final seconds = _visitDuration.inSeconds % 60;

      return Column(
        children: [
          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Text(
                  hours > 0
                      ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                      : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Stop slider
          _buildSlideToAction(
            label: 'Glissez pour terminer',
            icon: Icons.stop,
            color: Colors.red,
            onSlideComplete: _stopVisit,
          ),
        ],
      );
    } else {
      // No active visit - show start slider
      return _buildSlideToAction(
        label: 'Glissez pour démarrer la visite',
        icon: Icons.play_arrow,
        color: Colors.green,
        onSlideComplete: _startVisit,
      );
    }
  }

  Widget _buildSlideToAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onSlideComplete,
  }) {
    return SlideToActionWidget(
      label: label,
      icon: icon,
      color: color,
      onSlideComplete: onSlideComplete,
    );
  }
}

// Custom slide-to-action widget (like slide to unlock)
class SlideToActionWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onSlideComplete;

  const SlideToActionWidget({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onSlideComplete,
  });

  @override
  State<SlideToActionWidget> createState() => _SlideToActionWidgetState();
}

class _SlideToActionWidgetState extends State<SlideToActionWidget> {
  double _dragPosition = 0;
  bool _isCompleted = false;

  static const double _sliderHeight = 60;
  static const double _thumbSize = 50;

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx)
          .clamp(0.0, maxWidth - _thumbSize);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxWidth) {
    // If dragged more than 80% of the way, complete the action
    if (_dragPosition > (maxWidth - _thumbSize) * 0.8) {
      setState(() {
        _dragPosition = maxWidth - _thumbSize;
        _isCompleted = true;
      });
      widget.onSlideComplete();

      // Reset after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _dragPosition = 0;
            _isCompleted = false;
          });
        }
      });
    } else {
      // Animate back to start
      setState(() {
        _dragPosition = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return Container(
          height: _sliderHeight,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(_sliderHeight / 2),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Progress background
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: _sliderHeight,
                width: _dragPosition + _thumbSize,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(_sliderHeight / 2),
                ),
              ),

              // Label
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // Draggable thumb
              AnimatedPositioned(
                duration: _isCompleted
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                curve: Curves.easeOut,
                left: _dragPosition,
                top: (_sliderHeight - _thumbSize) / 2,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onHorizontalDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (details) =>
                      _onHorizontalDragEnd(details, maxWidth),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Full screen photo viewer with swipe and delete functionality
class _FullScreenPhotoViewer extends StatefulWidget {
  final List<ClientPhoto> apiPhotos;
  final List<Uint8List> localPhotoBytes;
  final int initialIndex;
  final Function(int) onDelete;
  final String baseUrl;

  const _FullScreenPhotoViewer({
    required this.apiPhotos,
    required this.localPhotoBytes,
    required this.initialIndex,
    required this.onDelete,
    required this.baseUrl,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  int get _totalPhotosCount => widget.apiPhotos.length + widget.localPhotoBytes.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isApiPhoto(int index) {
    return index < widget.apiPhotos.length;
  }

  void _deleteCurrentPhoto() {
    // Only allow deleting local photos, not API photos
    if (_isApiPhoto(_currentIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les photos du serveur ne peuvent pas être supprimées ici'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: const Text('Voulez-vous vraiment supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Calculate local photo index
              final localIndex = _currentIndex - widget.apiPhotos.length;
              widget.onDelete(localIndex);
              if (_totalPhotosCount <= 1) {
                Navigator.pop(context); // Close viewer if no photos left
              } else {
                setState(() {
                  if (_currentIndex >= _totalPhotosCount - 1) {
                    _currentIndex = _totalPhotosCount - 2;
                  }
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoWidget(int index) {
    if (_isApiPhoto(index)) {
      // API photo - use NetworkImage
      final apiPhoto = widget.apiPhotos[index];
      final photoUrl = apiPhoto.getFullUrl(widget.baseUrl);
      return Image.network(
        photoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          );
        },
      );
    } else {
      // Local photo - use MemoryImage (works on both web and mobile)
      final localIndex = index - widget.apiPhotos.length;
      return Image.memory(
        widget.localPhotoBytes[localIndex],
        fit: BoxFit.contain,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / $_totalPhotosCount'),
        actions: [
          // Only show delete button for local photos
          if (!_isApiPhoto(_currentIndex))
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrentPhoto,
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: _totalPhotosCount,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: _buildPhotoWidget(index),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet widget for displaying orders with API loading
class _OrdersBottomSheet extends StatefulWidget {
  final int clientId;
  final OrderService orderService;
  final bool isVisitActive;
  final VoidCallback onCreateOrder;

  const _OrdersBottomSheet({
    required this.clientId,
    required this.orderService,
    required this.isVisitActive,
    required this.onCreateOrder,
  });

  @override
  State<_OrdersBottomSheet> createState() => _OrdersBottomSheetState();
}

class _OrdersBottomSheetState extends State<_OrdersBottomSheet> {
  List<ApiOrder> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.orderService.listOrders(
        clientId: widget.clientId,
      );

      if (mounted) {
        setState(() {
          _orders = response.orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatOrderDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final orderDate = DateTime(date.year, date.month, date.day);

      if (orderDate == today) {
        return "Aujourd'hui";
      } else if (orderDate == yesterday) {
        return 'Hier';
      } else {
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildApiOrderCard(ApiOrder order) {
    Color statusColor;
    String statusText;

    switch (order.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        statusText = 'Confirmée';
        break;
      case 'processing':
        statusColor = Colors.purple;
        statusText = 'En cours';
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusText = 'Livrée';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context); // Close the bottom sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApiOrderDetailPage(orderId: order.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande #${order.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatOrderDate(order.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.orderItems.length} article${order.orderItems.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###', 'fr_FR').format(order.totalAmount)} ${order.currency}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.reference != null && order.reference!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Réf: ${order.reference!}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Commandes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // New Order Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isVisitActive ? widget.onCreateOrder : null,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle Commande'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isVisitActive ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Warning message if visit not active
          if (!widget.isVisitActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Démarrez la visite pour créer une nouvelle commande',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadOrders,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucune commande précédente',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Créez votre première commande',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              return _buildApiOrderCard(order);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Stateful bottom sheet widget that fetches alerts from API
class _AlertsBottomSheet extends StatefulWidget {
  final int clientId;
  final AlertApiService alertApiService;
  final bool isVisitActive;
  final VoidCallback onCreateAlert;

  const _AlertsBottomSheet({
    required this.clientId,
    required this.alertApiService,
    required this.isVisitActive,
    required this.onCreateAlert,
  });

  @override
  State<_AlertsBottomSheet> createState() => _AlertsBottomSheetState();
}

class _AlertsBottomSheetState extends State<_AlertsBottomSheet> {
  List<ApiAlert> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.alertApiService.getAlertsForClient(
        widget.clientId,
      );

      if (mounted) {
        setState(() {
          _alerts = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatAlertDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final alertDate = DateTime(date.year, date.month, date.day);

    if (alertDate == today) {
      return "Aujourd'hui ${DateFormat('HH:mm').format(date)}";
    } else if (alertDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'rupture_grave':
        return Icons.inventory_2;
      case 'litige_probleme':
        return Icons.payment;
      case 'probleme_rayon':
        return Icons.shelves;
      case 'risque_perte':
        return Icons.warning;
      case 'demande_speciale':
        return Icons.star;
      case 'opportunite':
        return Icons.lightbulb;
      default:
        return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'rupture_grave':
        return AppColors.primary;
      case 'litige_probleme':
        return AppColors.primaryDark;
      case 'probleme_rayon':
        return AppColors.secondary;
      case 'risque_perte':
        return AppColors.primary;
      case 'demande_speciale':
        return AppColors.secondaryDark;
      case 'opportunite':
        return AppColors.secondary;
      default:
        return AppColors.accent;
    }
  }

  Widget _buildAlertCard(ApiAlert alert) {
    final statusColor = _getStatusColor(alert.status);
    final typeIcon = _getTypeIcon(alert.type);
    final typeColor = _getTypeColor(alert.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context); // Close the bottom sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlertDetailPage(alert: alert),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      typeIcon,
                      color: typeColor,
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
                                alert.typeLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                alert.statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.comment,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              _formatAlertDate(alert.createdAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                            if (alert.photos.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.photo, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${alert.photos.length}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alertes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // New Alert Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isVisitActive ? widget.onCreateAlert : null,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle Alerte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isVisitActive ? Colors.orange : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Warning message if visit not active
          if (!widget.isVisitActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Démarrez la visite pour créer une nouvelle alerte',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(),

          // Alerts List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadAlerts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _alerts.isEmpty
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
                                  'Aucune alerte précédente',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Créez votre première alerte',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) {
                              final alert = _alerts[index];
                              return _buildAlertCard(alert);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Stateful bottom sheet widget that fetches visit reports from API
class _VisitReportsBottomSheet extends StatefulWidget {
  final int clientId;
  final String clientName;
  final bool isVisitActive;
  final VisitApiService visitApiService;
  final VoidCallback onNewReport;
  final Function(VisitReport) onViewReport;

  const _VisitReportsBottomSheet({
    required this.clientId,
    required this.clientName,
    required this.isVisitActive,
    required this.visitApiService,
    required this.onNewReport,
    required this.onViewReport,
  });

  @override
  State<_VisitReportsBottomSheet> createState() => _VisitReportsBottomSheetState();
}

class _VisitReportsBottomSheetState extends State<_VisitReportsBottomSheet> {
  List<VisitReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiReports = await widget.visitApiService.getClientVisitReports(widget.clientId);
      if (mounted) {
        setState(() {
          _reports = apiReports.map((r) => r.toVisitReport()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rapports de visite',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // New Report Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isVisitActive ? widget.onNewReport : null,
                icon: const Icon(Icons.add),
                label: const Text('Nouveau Rapport de Visite'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isVisitActive ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Warning message if visit not active
          if (!widget.isVisitActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Démarrez la visite pour créer un nouveau rapport',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(),

          // Content area: Loading, Error, Empty, or Reports List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des rapports...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadReports,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _reports.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun rapport précédent',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Créez votre premier rapport',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReports,
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                final report = _reports[index];
                                return _buildVisitReportCard(report);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitReportCard(VisitReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => widget.onViewReport(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatReportDate(report.startTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Durée: ${_calculateDuration(report.startTime, report.endTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildReportStatusBadge(report.status),
                ],
              ),
              const SizedBox(height: 12),

              // Quick info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildReportInfoRow(
                      Icons.person,
                      'Gérant présent',
                      report.gerantPresent == true ? 'Oui' : report.gerantPresent == false ? 'Non' : 'Non renseigné',
                      report.gerantPresent == true ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildReportInfoRow(
                      Icons.shopping_cart,
                      'Commande',
                      report.orderPlaced == true
                          ? 'Oui${report.orderAmount != null ? ' (${report.orderAmount!.toStringAsFixed(0)} FCFA)' : ''}'
                          : report.orderPlaced == false ? 'Non' : 'Non renseigné',
                      report.orderPlaced == true ? Colors.green : Colors.grey,
                    ),
                    if (report.shelfPhoto != null || report.additionalPhotos.isNotEmpty || report.shelfPhotos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildReportInfoRow(
                        Icons.photo_camera,
                        'Photos',
                        '${report.totalPhotoCount} photo(s)',
                        Colors.blue,
                      ),
                    ],
                  ],
                ),
              ),

              // Comments preview
              if (report.comments != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.comments!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportStatusBadge(VisitReportStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case VisitReportStatus.incomplete:
        color = Colors.orange;
        icon = Icons.pending;
        label = 'Incomplet';
        break;
      case VisitReportStatus.validated:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Validé';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  String _formatReportDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final reportDate = DateTime(date.year, date.month, date.day);

    if (reportDate == today) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (reportDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE HH:mm', 'fr_FR').format(date);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  String _calculateDuration(DateTime start, DateTime? end) {
    if (end == null) return 'En cours';
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }
}

/// Full screen location picker page for adjusting GPS position
class _LocationPickerPage extends StatefulWidget {
  final LatLng initialPosition;
  final double maxRadius;

  const _LocationPickerPage({
    required this.initialPosition,
    required this.maxRadius,
  });

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  late LatLng _currentPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.initialPosition;
  }

  /// Calculate distance between two LatLng points in meters using Haversine formula
  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double lat1 = from.latitude * math.pi / 180;
    final double lat2 = to.latitude * math.pi / 180;
    final double deltaLat = (to.latitude - from.latitude) * math.pi / 180;
    final double deltaLng = (to.longitude - from.longitude) * math.pi / 180;

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance(widget.initialPosition, _currentPosition);
    final isWithinRadius = distance <= widget.maxRadius;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ajuster la position'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: Column(
        children: [
          // Header with instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                Text(
                  'Déplacez la carte pour ajuster la position (max ${widget.maxRadius.toInt()}m)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Distance indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isWithinRadius
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isWithinRadius ? AppColors.success : AppColors.error,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWithinRadius ? Icons.check_circle : Icons.warning,
                        size: 20,
                        color: isWithinRadius ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Distance: ${distance.toInt()}m / ${widget.maxRadius.toInt()}m',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isWithinRadius ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Map with fixed center marker
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.initialPosition,
                    zoom: 18,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (CameraPosition position) {
                    setState(() {
                      _currentPosition = position.target;
                    });
                  },
                  markers: {
                    // Original GPS position marker (blue) - stays fixed on map
                    Marker(
                      markerId: const MarkerId('original_location'),
                      position: widget.initialPosition,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('radius_limit'),
                      center: widget.initialPosition,
                      radius: widget.maxRadius,
                      fillColor: AppColors.primary.withValues(alpha: 0.1),
                      strokeColor: AppColors.primary.withValues(alpha: 0.5),
                      strokeWidth: 2,
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Fixed center marker (red pin icon)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: isWithinRadius ? AppColors.error : Colors.grey,
                    ),
                  ),
                ),
                // Marker shadow/dot at the bottom of pin
                Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Zoom controls
                Positioned(
                  right: 16,
                  bottom: 120,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                        child: const Icon(Icons.add, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomOut());
                        },
                        child: const Icon(Icons.remove, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                // Reset to GPS position button
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'reset',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(widget.initialPosition),
                      );
                    },
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    label: const Text(
                      'Position GPS',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
                // Warning when outside radius
                if (!isWithinRadius)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Position trop éloignée du point GPS!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bottom buttons
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isWithinRadius
                        ? () => Navigator.pop(context, _currentPosition)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirmer la position',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Return Vouchers Bottom Sheet
// ============================================================

class _ReturnVouchersBottomSheet extends StatefulWidget {
  final int clientId;
  final String clientName;
  final bool isVisitActive;
  final VoidCallback onCreateReturnVoucher;

  const _ReturnVouchersBottomSheet({
    required this.clientId,
    required this.clientName,
    required this.isVisitActive,
    required this.onCreateReturnVoucher,
  });

  @override
  State<_ReturnVouchersBottomSheet> createState() =>
      _ReturnVouchersBottomSheetState();
}

class _ReturnVouchersBottomSheetState
    extends State<_ReturnVouchersBottomSheet> {
  final ReturnVoucherService _service = ReturnVoucherService();
  List<ReturnVoucher> _vouchers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _service.getReturnVouchers(
        clientId: widget.clientId,
      );

      if (mounted) {
        setState(() {
          _vouchers = response.vouchers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.gray;
      case 'submitted':
        return Colors.orange;
      case 'validated':
        return AppColors.success;
      case 'cancelled':
        return AppColors.primary;
      default:
        return AppColors.gray;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final voucherDate = DateTime(date.year, date.month, date.day);

    if (voucherDate == today) {
      return "Aujourd'hui ${DateFormat('HH:mm').format(date)}";
    } else if (voucherDate == yesterday) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formatted FCFA';
  }

  Widget _buildVoucherCard(ReturnVoucher voucher) {
    final statusColor = _getStatusColor(voucher.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReturnVoucherDetailPage(voucherId: voucher.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_return,
                      color: AppColors.secondaryDark,
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
                                voucher.reference,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                voucher.statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatAmount(voucher.totalAmount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(voucher.createdAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.inventory_2,
                                size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${voucher.items.length} article${voucher.items.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bons de Retour',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),

          // New Return Voucher Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.isVisitActive
                    ? widget.onCreateReturnVoucher
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Nouveau Bon de Retour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isVisitActive
                      ? AppColors.secondaryDark
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Warning message if visit not active
          if (!widget.isVisitActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Démarrez la visite pour créer un nouveau bon de retour',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(),

          // Vouchers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _loadVouchers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _vouchers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_return,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun bon de retour',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Créez votre premier bon de retour',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _vouchers.length,
                            itemBuilder: (context, index) {
                              return _buildVoucherCard(_vouchers[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
