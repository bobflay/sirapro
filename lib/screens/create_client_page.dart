import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sirapro/models/create_client_request.dart';
import 'package:sirapro/models/user.dart';
import 'package:sirapro/services/api_service.dart';
import 'package:sirapro/services/auth_service.dart';
import 'package:sirapro/services/client_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:image_picker/image_picker.dart';

class CreateClientPage extends StatefulWidget {
  const CreateClientPage({super.key});

  @override
  State<CreateClientPage> createState() => _CreateClientPageState();
}

class _CreateClientPageState extends State<CreateClientPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final PageController _pageController = PageController();

  // Services
  final ClientService _clientService = ClientService();
  final AuthService _authService = AuthService();

  // Loading and error states
  bool _isLoading = false;
  bool _isUploadingPhotos = false;
  String? _uploadProgress;

  // User data for base_commerciale_id and zone_id
  User? _currentUser;
  List<Zone> _availableZones = [];
  Zone? _selectedZoneObject;

  // Client code (auto-generated or user input)
  final _codeController = TextEditingController();

  // Administrative Data
  final _boutiqueNameController = TextEditingController();
  String? _selectedType;
  final _gerantNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _quartierController = TextEditingController();
  final _villeController = TextEditingController();

  // Geographic Data
  String? _gpsLocation;
  String? _selectedZone;

  // GPS Location picker state
  LatLng? _originalGpsPosition; // The position from GPS sensor
  LatLng? _adjustedGpsPosition; // The position after user adjustment
  static const double _maxAdjustmentRadius = 300.0; // Maximum adjustment radius in meters

  // Visual Data
  File? _facadePhoto;
  File? _rayonsPhoto;
  final List<File> _additionalPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Commercial Data
  String? _potentiel;
  String? _frequenceVisite;

  // Validation state
  bool _showValidationErrors = false;
  Map<String, String> _fieldErrors = {};

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

  // Zones are now loaded from user data dynamically

  final List<String> _potentiels = ['A', 'B', 'C'];

  final List<String> _frequences = [
    'Hebdomadaire',
    'Bimensuelle',
    'Mensuelle',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _generateClientCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _boutiqueNameController.dispose();
    _gerantNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _quartierController.dispose();
    _villeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Load the current user data to get base_commerciale_id and zones
  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _availableZones = user.zones;
          // Auto-select first zone if available
          if (_availableZones.isNotEmpty) {
            _selectedZoneObject = _availableZones.first;
            _selectedZone = _selectedZoneObject!.name;
          }
        });
      }
    } catch (e) {
      // Silently fail - user can still create client with manual zone selection
      debugPrint('Failed to load user data: $e');
    }
  }

  /// Generate a unique client code based on timestamp
  void _generateClientCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _codeController.text = 'CLT$timestamp';
  }

  void _goToStep(int step) {
    // Only allow going back or to same step without validation
    if (step < _currentStep) {
      setState(() {
        _currentStep = step;
      });
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Validate all steps up to the target step
    for (int i = _currentStep; i < step; i++) {
      if (!_validateStep(i)) {
        return;
      }
    }

    if (step >= 0 && step <= 3) {
      setState(() {
        _currentStep = step;
      });
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateStep(int step) {
    _fieldErrors = {};

    switch (step) {
      case 0: // Administrative Data
        if (_boutiqueNameController.text.trim().isEmpty) {
          _fieldErrors['boutiqueName'] = 'Ce champ est requis';
        }
        if (_selectedType == null) {
          _fieldErrors['type'] = 'Veuillez sélectionner un type';
        }
        if (_gerantNameController.text.trim().isEmpty) {
          _fieldErrors['gerantName'] = 'Ce champ est requis';
        }
        if (_phoneController.text.trim().isEmpty) {
          _fieldErrors['phone'] = 'Ce champ est requis';
        }
        break;

      case 1: // Geographic Data
        if (_quartierController.text.trim().isEmpty) {
          _fieldErrors['quartier'] = 'Ce champ est requis';
        }
        if (_villeController.text.trim().isEmpty) {
          _fieldErrors['ville'] = 'Ce champ est requis';
        }
        if (_addressController.text.trim().isEmpty) {
          _fieldErrors['address'] = 'Ce champ est requis';
        }
        if (_selectedZoneObject == null) {
          _fieldErrors['zone'] = 'Veuillez sélectionner une zone';
        }
        if (_gpsLocation == null) {
          _fieldErrors['gps'] = 'La position GPS est requise';
        }
        break;

      case 2: // Visual Data
        if (_facadePhoto == null) {
          _fieldErrors['facadePhoto'] = 'La photo de façade est requise';
        }
        if (_rayonsPhoto == null) {
          _fieldErrors['rayonsPhoto'] = 'La photo des rayons est requise';
        }
        break;

      case 3: // Commercial Data
        if (_potentiel == null) {
          _fieldErrors['potentiel'] = 'Veuillez sélectionner un potentiel';
        }
        if (_frequenceVisite == null) {
          _fieldErrors['frequence'] = 'Veuillez sélectionner une fréquence';
        }
        break;
    }

    if (_fieldErrors.isNotEmpty) {
      setState(() {
        _showValidationErrors = true;
      });
      return false;
    }

    setState(() {
      _showValidationErrors = false;
    });
    return true;
  }

  String? _getFieldError(String fieldKey) {
    return _showValidationErrors ? _fieldErrors[fieldKey] : null;
  }

  Future<void> _showPhotoSourceDialog({
    required String title,
    required Function(File) onPhotoSelected,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Appareil photo',
                  color: AppColors.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    await _capturePhoto(ImageSource.camera, onPhotoSelected);
                  },
                ),
                _buildPhotoSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  color: AppColors.secondary,
                  onTap: () async {
                    Navigator.pop(context);
                    await _capturePhoto(ImageSource.gallery, onPhotoSelected);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source, Function(File) onPhotoSelected) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        onPhotoSelected(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la capture: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addAdditionalPhotos() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var pickedFile in pickedFiles) {
            _additionalPhotos.add(File(pickedFile.path));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) {
      return;
    }

    if (_currentStep < 3) {
      _goToStep(_currentStep + 1);
    } else {
      _saveClient();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _captureGPSLocation() async {
    try {
      // Use Geolocator's permission handling instead of permission_handler
      // to avoid iOS bug where permissions are incorrectly marked as denied
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La permission de localisation est requise pour enregistrer la position GPS.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog();
        }
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez activer le service de localisation dans les paramètres de votre appareil.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Obtention de la position GPS...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // Store the original GPS position
      final gpsPosition = LatLng(position.latitude, position.longitude);

      // Show the map picker for fine-tuning
      if (mounted) {
        final adjustedPosition = await _showLocationPickerDialog(gpsPosition);
        if (adjustedPosition != null) {
          setState(() {
            _originalGpsPosition = gpsPosition;
            _adjustedGpsPosition = adjustedPosition;
            _gpsLocation = '${adjustedPosition.latitude.toStringAsFixed(6)}, ${adjustedPosition.longitude.toStringAsFixed(6)}';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Position GPS enregistrée avec succès'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'obtention de la position GPS: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show the location picker as a full screen page
  /// Uses a fixed center marker - user moves the map to adjust position
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

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if we have required data
    if (_currentUser == null) {
      _showErrorSnackbar('Données utilisateur non disponibles. Veuillez vous reconnecter.');
      return;
    }

    // Parse GPS coordinates
    double? latitude;
    double? longitude;
    if (_gpsLocation != null) {
      final coords = _gpsLocation!.split(',');
      if (coords.length == 2) {
        latitude = double.tryParse(coords[0].trim());
        longitude = double.tryParse(coords[1].trim());
      }
    }

    if (latitude == null || longitude == null) {
      _showErrorSnackbar('La position GPS est requise. Veuillez capturer votre position.');
      return;
    }

    // Get base_commerciale_id and zone_id
    final baseCommercialeId = _currentUser!.primaryBase?.id;
    final zoneId = _selectedZoneObject?.id;

    if (baseCommercialeId == null) {
      _showErrorSnackbar('Base commerciale non configurée. Contactez votre administrateur.');
      return;
    }

    if (zoneId == null) {
      _showErrorSnackbar('Veuillez sélectionner une zone.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Show loading dialog
    _showLoadingDialog('Création du client en cours...');

    try {
      // Create the client request
      final request = CreateClientRequest(
        code: _codeController.text.trim(),
        name: _boutiqueNameController.text.trim(),
        type: _selectedType ?? 'Boutique',
        potential: _potentiel ?? 'C',
        baseCommercialeId: baseCommercialeId,
        zoneId: zoneId,
        managerName: _gerantNameController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim().isNotEmpty
            ? _whatsappController.text.trim()
            : null,
        email: null,
        city: _villeController.text.trim(),
        district: _quartierController.text.trim().isNotEmpty
            ? _quartierController.text.trim()
            : null,
        addressDescription: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        latitude: latitude,
        longitude: longitude,
        visitFrequency: CreateClientRequest.frequencyToApiValue(_frequenceVisite ?? 'Autre'),
        isActive: true,
      );

      // Create the client via API
      final createdClient = await _clientService.createClient(request);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Upload photos if any
      await _uploadClientPhotos(createdClient.id);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Client "${createdClient.name}" créé avec succès'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      // Return the created client
      Navigator.of(context).pop(createdClient);
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Handle validation errors
      if (e.statusCode == 422) {
        _showValidationErrorDialog(e.message);
      } else if (e.statusCode == 401) {
        _showErrorSnackbar('Session expirée. Veuillez vous reconnecter.');
      } else {
        _showErrorSnackbar(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackbar('Une erreur inattendue s\'est produite: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Upload photos for the created client
  Future<void> _uploadClientPhotos(int clientId) async {
    final photosToUpload = <MapEntry<File, String>>[];

    // Collect all photos with their types
    if (_facadePhoto != null) {
      photosToUpload.add(MapEntry(_facadePhoto!, 'facade'));
    }
    if (_rayonsPhoto != null) {
      photosToUpload.add(MapEntry(_rayonsPhoto!, 'shelves'));
    }
    for (final photo in _additionalPhotos) {
      photosToUpload.add(MapEntry(photo, 'other'));
    }

    if (photosToUpload.isEmpty) {
      return;
    }

    setState(() {
      _isUploadingPhotos = true;
      _uploadProgress = 'Téléchargement des photos: 0/${photosToUpload.length}';
    });

    _showLoadingDialog('Téléchargement des photos...');

    // Parse GPS coordinates for photos
    double? latitude;
    double? longitude;
    if (_gpsLocation != null) {
      final coords = _gpsLocation!.split(',');
      if (coords.length == 2) {
        latitude = double.tryParse(coords[0].trim());
        longitude = double.tryParse(coords[1].trim());
      }
    }

    int uploadedCount = 0;
    final List<String> errors = [];

    // Upload photos in batches by type for better organization
    // First upload facade photo
    if (_facadePhoto != null) {
      try {
        await _clientService.uploadSinglePhoto(
          clientId,
          _facadePhoto!,
          type: 'facade',
          latitude: latitude,
          longitude: longitude,
        );
        uploadedCount++;
        if (mounted) {
          setState(() {
            _uploadProgress = 'Téléchargement des photos: $uploadedCount/${photosToUpload.length}';
          });
        }
      } catch (e) {
        errors.add('Photo façade: ${e.toString()}');
      }
    }

    // Upload shelves photo
    if (_rayonsPhoto != null) {
      try {
        await _clientService.uploadSinglePhoto(
          clientId,
          _rayonsPhoto!,
          type: 'shelves',
          latitude: latitude,
          longitude: longitude,
        );
        uploadedCount++;
        if (mounted) {
          setState(() {
            _uploadProgress = 'Téléchargement des photos: $uploadedCount/${photosToUpload.length}';
          });
        }
      } catch (e) {
        errors.add('Photo rayons: ${e.toString()}');
      }
    }

    // Upload additional photos (in batches of up to 10)
    if (_additionalPhotos.isNotEmpty) {
      // Split into batches of 10
      for (int i = 0; i < _additionalPhotos.length; i += 10) {
        final batch = _additionalPhotos.skip(i).take(10).toList();
        try {
          await _clientService.uploadMultiplePhotos(
            clientId,
            batch,
            type: 'other',
            latitude: latitude,
            longitude: longitude,
          );
          uploadedCount += batch.length;
          if (mounted) {
            setState(() {
              _uploadProgress = 'Téléchargement des photos: $uploadedCount/${photosToUpload.length}';
            });
          }
        } catch (e) {
          errors.add('Photos additionnelles: ${e.toString()}');
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      setState(() {
        _isUploadingPhotos = false;
        _uploadProgress = null;
      });

      // Show warning if some photos failed to upload
      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${photosToUpload.length - errors.length}/${photosToUpload.length} photos téléchargées. Certaines photos ont échoué.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
            if (_uploadProgress != null) ...[
              const SizedBox(height: 8),
              Text(
                _uploadProgress!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
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
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Erreur de validation'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const SessionAwareAppBar(
        title: 'Nouveau Client',
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Horizontal Stepper
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: EasyStepper(
                activeStep: _currentStep,
                lineStyle: LineStyle(
                  lineLength: 50,
                  lineType: LineType.normal,
                  lineThickness: 3,
                  lineSpace: 4,
                  activeLineColor: AppColors.primary,
                  finishedLineColor: AppColors.success,
                  unreachedLineColor: Colors.grey[300]!,
                ),
                stepShape: StepShape.circle,
                stepBorderRadius: 15,
                borderThickness: 2,
                stepRadius: 28,
                finishedStepBorderColor: AppColors.success,
                finishedStepTextColor: AppColors.success,
                finishedStepBackgroundColor: AppColors.success,
                activeStepIconColor: Colors.white,
                activeStepBorderColor: AppColors.primary,
                activeStepBackgroundColor: AppColors.primary,
                activeStepTextColor: AppColors.primary,
                unreachedStepBackgroundColor: Colors.white,
                unreachedStepBorderColor: Colors.grey[300]!,
                unreachedStepIconColor: Colors.grey[400]!,
                unreachedStepTextColor: Colors.grey[500]!,
                showLoadingAnimation: false,
                enableStepTapping: true,
                onStepReached: (index) {
                  _goToStep(index);
                },
                steps: [
                  EasyStep(
                    customStep: _buildStepIcon(0, Icons.person),
                    title: 'Admin',
                  ),
                  EasyStep(
                    customStep: _buildStepIcon(1, Icons.location_on),
                    title: 'Géo',
                  ),
                  EasyStep(
                    customStep: _buildStepIcon(2, Icons.camera_alt),
                    title: 'Photos',
                  ),
                  EasyStep(
                    customStep: _buildStepIcon(3, Icons.business),
                    title: 'Commercial',
                  ),
                ],
              ),
            ),

            // Step Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryVeryLight,
              child: Text(
                _getStepTitle(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildAdministrativeDataStep(),
                  _buildGeographicDataStep(),
                  _buildVisualDataStep(),
                  _buildCommercialDataStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Container(
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
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousStep,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Précédent'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 1,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _isUploadingPhotos ? null : _nextStep,
                      icon: _isLoading || _isUploadingPhotos
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(_currentStep == 3 ? Icons.check : Icons.arrow_forward),
                      label: Text(_isLoading
                          ? 'Création...'
                          : _isUploadingPhotos
                              ? 'Téléchargement...'
                              : _currentStep == 3
                                  ? 'Créer le client'
                                  : 'Suivant'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _currentStep == 3 ? AppColors.success : AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildStepIcon(int stepIndex, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppColors.success
            : isActive
                ? AppColors.primary
                : Colors.white,
        border: Border.all(
          color: isCompleted
              ? AppColors.success
              : isActive
                  ? AppColors.primary
                  : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Icon(
        isCompleted ? Icons.check : icon,
        color: isCompleted || isActive ? Colors.white : Colors.grey[400],
        size: 24,
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Données administratives';
      case 1:
        return 'Données géographiques';
      case 2:
        return 'Données visuelles';
      case 3:
        return 'Données commerciales';
      default:
        return '';
    }
  }

  Widget _buildAdministrativeDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField(
            controller: _boutiqueNameController,
            label: 'Nom de la boutique',
            icon: Icons.store,
            isRequired: true,
            errorText: _getFieldError('boutiqueName'),
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _selectedType,
            label: 'Type de client',
            icon: Icons.category,
            items: _types,
            isRequired: true,
            errorText: _getFieldError('type'),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _gerantNameController,
            label: 'Nom du gérant',
            icon: Icons.person,
            isRequired: true,
            errorText: _getFieldError('gerantName'),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: 'Téléphone',
            icon: Icons.phone,
            isRequired: true,
            keyboardType: TextInputType.phone,
            errorText: _getFieldError('phone'),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _whatsappController,
            label: 'WhatsApp',
            icon: Icons.chat,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildGeographicDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField(
            controller: _villeController,
            label: 'Ville',
            icon: Icons.location_on,
            isRequired: true,
            errorText: _getFieldError('ville'),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quartierController,
            label: 'Quartier',
            icon: Icons.location_city,
            isRequired: true,
            errorText: _getFieldError('quartier'),
          ),
          const SizedBox(height: 16),
          _buildZoneDropdown(),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Adresse complète',
            icon: Icons.home,
            isRequired: true,
            maxLines: 2,
            errorText: _getFieldError('address'),
          ),
          const SizedBox(height: 20),
          _buildGPSButton(),
        ],
      ),
    );
  }

  Widget _buildGPSButton() {
    final hasError = _getFieldError('gps') != null;
    final hasLocation = _gpsLocation != null;

    // Determine colors based on state
    Color getBackgroundColor() {
      if (hasLocation) return AppColors.success.withValues(alpha: 0.1);
      if (hasError) return AppColors.error.withValues(alpha: 0.1);
      return Colors.transparent;
    }

    Color getBorderColor() {
      if (hasLocation) return AppColors.success;
      if (hasError) return AppColors.error;
      return Colors.transparent;
    }

    Color getIconColor() {
      if (hasLocation) return AppColors.success;
      if (hasError) return AppColors.error;
      return Colors.white;
    }

    Color getTextColor() {
      if (hasLocation) return AppColors.success;
      if (hasError) return AppColors.error;
      return Colors.white;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: hasLocation || hasError
                ? null
                : LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
            color: hasLocation || hasError ? getBackgroundColor() : null,
            border: hasLocation || hasError
                ? Border.all(color: getBorderColor(), width: 2)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _captureGPSLocation,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasLocation
                          ? Icons.check_circle
                          : hasError
                              ? Icons.error_outline
                              : Icons.my_location,
                      color: getIconColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasLocation
                                ? 'Position GPS enregistrée'
                                : 'Enregistrer la position GPS *',
                            style: TextStyle(
                              color: getTextColor(),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasLocation)
                            Text(
                              _gpsLocation!,
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                              ),
                            ),
                          if (hasError && !hasLocation)
                            Text(
                              'Appuyez pour capturer votre position',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasLocation)
                      IconButton(
                        onPressed: _captureGPSLocation,
                        icon: Icon(Icons.refresh, color: AppColors.success),
                        tooltip: 'Actualiser',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError && !hasLocation)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  _getFieldError('gps')!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildZoneDropdown() {
    final hasError = _getFieldError('zone') != null;
    final zoneNames = _availableZones.map((z) => z.name).toList();

    // If no zones available, show a message
    if (_availableZones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zones non disponibles',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aucune zone n\'est configurée pour votre compte. Contactez votre administrateur.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: hasError ? Border.all(color: AppColors.error, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? AppColors.error.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedZone,
            decoration: InputDecoration(
              labelText: 'Zone / Secteur *',
              labelStyle: TextStyle(
                color: hasError ? AppColors.error : null,
              ),
              prefixIcon: Icon(
                Icons.map,
                color: hasError ? AppColors.error : AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items: zoneNames.map((zoneName) {
              return DropdownMenuItem(
                value: zoneName,
                child: Text(zoneName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedZone = value;
                // Find and store the selected zone object
                _selectedZoneObject = _availableZones.firstWhere(
                  (z) => z.name == value,
                  orElse: () => _availableZones.first,
                );
              });
            },
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  _getFieldError('zone')!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVisualDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Photos obligatoires', Icons.camera_alt),
          const SizedBox(height: 16),
          _buildPhotoCard(
            label: 'Photo de façade',
            description: 'Prenez une photo de la devanture de la boutique',
            icon: Icons.store,
            photo: _facadePhoto,
            isRequired: true,
            errorText: _getFieldError('facadePhoto'),
            onTap: () {
              _showPhotoSourceDialog(
                title: 'Photo de façade',
                onPhotoSelected: (file) {
                  setState(() {
                    _facadePhoto = file;
                    _fieldErrors.remove('facadePhoto');
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          _buildPhotoCard(
            label: 'Photo des rayons',
            description: 'Prenez une photo des rayons de produits',
            icon: Icons.shelves,
            photo: _rayonsPhoto,
            isRequired: true,
            errorText: _getFieldError('rayonsPhoto'),
            onTap: () {
              _showPhotoSourceDialog(
                title: 'Photo des rayons',
                onPhotoSelected: (file) {
                  setState(() {
                    _rayonsPhoto = file;
                    _fieldErrors.remove('rayonsPhoto');
                  });
                },
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Photos complémentaires', Icons.add_photo_alternate),
          const SizedBox(height: 16),
          _buildAddPhotosButton(),
          if (_additionalPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAdditionalPhotosGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard({
    required String label,
    required String description,
    required IconData icon,
    required File? photo,
    required VoidCallback onTap,
    bool isRequired = false,
    String? errorText,
  }) {
    final hasError = errorText != null;
    final hasPhoto = photo != null;

    Color getBorderColor() {
      if (hasPhoto) return AppColors.success;
      if (hasError) return AppColors.error;
      return Colors.grey[300]!;
    }

    Color getIconBgColor() {
      if (hasPhoto) return AppColors.success.withValues(alpha: 0.1);
      if (hasError) return AppColors.error.withValues(alpha: 0.1);
      return Colors.grey[100]!;
    }

    Color getIconColor() {
      if (hasPhoto) return AppColors.success;
      if (hasError) return AppColors.error;
      return Colors.grey[400]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: getBorderColor(),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasError
                      ? AppColors.error.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: getIconBgColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasPhoto ? Icons.check_circle : (hasError ? Icons.error_outline : icon),
                    color: getIconColor(),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasPhoto ? AppColors.success : (hasError ? AppColors.error : Colors.black87),
                            ),
                          ),
                          if (isRequired)
                            Text(
                              ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasError ? AppColors.error : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasPhoto ? Icons.edit : Icons.camera_alt,
                  color: hasPhoto ? AppColors.success : (hasError ? AppColors.error : AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAddPhotosButton() {
    return InkWell(
      onTap: _addAdditionalPhotos,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Ajouter des photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalPhotosGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_additionalPhotos.length} photo(s) ajoutée(s)',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: _addAdditionalPhotos,
                child: Text(
                  'Ajouter +',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _additionalPhotos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _additionalPhotos[index],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _additionalPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommercialDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Potentiel du client', Icons.trending_up),
          const SizedBox(height: 16),
          Row(
            children: _potentiels.map((potentiel) {
              final isSelected = _potentiel == potentiel;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _potentiel = isSelected ? null : potentiel;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  spreadRadius: 1,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            potentiel,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getPotentielLabel(potentiel),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildDropdownField(
            value: _frequenceVisite,
            label: 'Fréquence de visite recommandée',
            icon: Icons.calendar_today,
            items: _frequences,
            isRequired: true,
            errorText: _getFieldError('frequence'),
            onChanged: (value) {
              setState(() {
                _frequenceVisite = value;
              });
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryVeryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.secondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• L\'historique des visites sera disponible après la création\n• L\'historique des commandes sera disponible après la première commande',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPotentielLabel(String potentiel) {
    switch (potentiel) {
      case 'A':
        return 'Élevé';
      case 'B':
        return 'Moyen';
      case 'C':
        return 'Faible';
      default:
        return '';
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    String? errorText,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: hasError ? Border.all(color: AppColors.error, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? AppColors.error.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: isRequired ? '$label *' : label,
              labelStyle: TextStyle(
                color: hasError ? AppColors.error : null,
              ),
              hintText: hintText,
              prefixIcon: Icon(
                icon,
                color: hasError ? AppColors.error : AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isRequired = false,
    String? errorText,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: hasError ? Border.all(color: AppColors.error, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? AppColors.error.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              labelText: isRequired ? '$label *' : label,
              labelStyle: TextStyle(
                color: hasError ? AppColors.error : null,
              ),
              prefixIcon: Icon(
                icon,
                color: hasError ? AppColors.error : AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Full screen location picker page
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
