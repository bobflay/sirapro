import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sirapro/models/client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateClientPage extends StatefulWidget {
  const CreateClientPage({super.key});

  @override
  State<CreateClientPage> createState() => _CreateClientPageState();
}

class _CreateClientPageState extends State<CreateClientPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Administrative Data
  final _boutiqueNameController = TextEditingController();
  String? _selectedType;
  final _gerantNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _quartierController = TextEditingController();
  final _villeController = TextEditingController();
  final _itineraireController = TextEditingController();

  // Geographic Data
  String? _gpsLocation;
  String? _selectedZone;

  // Visual Data
  File? _facadePhoto;
  File? _rayonsPhoto;
  List<File> _additionalPhotos = [];

  // Commercial Data
  String? _potentiel;
  String? _frequenceVisite;

  final List<String> _types = [
    'Boutique',
    'Supermarché',
    'Demi-grossiste',
    'Grossiste',
    'Distributeur',
    'Autre',
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

  @override
  void dispose() {
    _boutiqueNameController.dispose();
    _gerantNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _quartierController.dispose();
    _villeController.dispose();
    _itineraireController.dispose();
    super.dispose();
  }

  Future<void> _captureGPSLocation() async {
    try {
      // Vérifier la permission de localisation
      PermissionStatus locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.location.request();
      }

      if (!locationStatus.isGranted) {
        if (mounted) {
          // Vérifier si refusé de manière permanente
          if (locationStatus.isPermanentlyDenied) {
            _showLocationPermissionDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('La permission de localisation est requise pour enregistrer la position GPS.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
        return;
      }

      // Vérifier si le service de localisation est activé
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

      // Afficher un indicateur de chargement
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

      // Obtenir la position GPS
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _gpsLocation = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position GPS enregistrée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Simulate save operation
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Create new Client object from form data
      final newClient = Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        boutiqueName: _boutiqueNameController.text.trim(),
        type: _selectedType ?? 'Boutique',
        gerantName: _gerantNameController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim().isNotEmpty
            ? _whatsappController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        address: _addressController.text.trim(),
        quartier: _quartierController.text.trim(),
        ville: _villeController.text.trim(),
        zone: _selectedZone,
        gpsLocation: _gpsLocation,
        potentiel: _potentiel,
        frequenceVisite: _frequenceVisite,
        status: 'En attente',
        isActive: false,
        createdAt: DateTime.now(),
      );

      // Return to clients page with the new client
      Navigator.of(context).pop(newClient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Nouveau Client'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() {
                _currentStep += 1;
              });
            } else {
              _saveClient();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep -= 1;
              });
            }
          },
          steps: [
            Step(
              title: const Text('Données administratives'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildAdministrativeDataStep(),
            ),
            Step(
              title: const Text('Données géographiques'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildGeographicDataStep(),
            ),
            Step(
              title: const Text('Données visuelles'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildVisualDataStep(),
            ),
            Step(
              title: const Text('Données commerciales'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: _buildCommercialDataStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdministrativeDataStep() {
    return Column(
      children: [
        TextFormField(
          controller: _boutiqueNameController,
          decoration: InputDecoration(
            labelText: 'Nom de la boutique *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le nom de la boutique';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: InputDecoration(
            labelText: 'Type *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _types.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedType = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner un type';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _gerantNameController,
          decoration: InputDecoration(
            labelText: 'Nom du gérant *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le nom du gérant';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Téléphone *',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le numéro de téléphone';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'WhatsApp',
            prefixIcon: const Icon(Icons.chat),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGeographicDataStep() {
    return Column(
      children: [
        TextFormField(
          controller: _quartierController,
          decoration: InputDecoration(
            labelText: 'Quartier *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer le quartier';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _villeController,
          decoration: InputDecoration(
            labelText: 'Ville *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer la ville';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Adresse complète *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer l\'adresse';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _itineraireController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description de l\'itinéraire',
            hintText: 'Comment accéder à la boutique...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedZone,
          decoration: InputDecoration(
            labelText: 'Zone / Secteur',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _zones.map((zone) {
            return DropdownMenuItem(
              value: zone,
              child: Text(zone),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedZone = value;
            });
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _captureGPSLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Enregistrer la position GPS'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_gpsLocation != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'GPS: $_gpsLocation',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisualDataStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Photos obligatoires',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildPhotoButton(
          label: 'Photo de façade *',
          icon: Icons.store,
          photo: _facadePhoto,
          onTap: () {
            // TODO: Take/select photo
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fonctionnalité photo à implémenter'),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildPhotoButton(
          label: 'Photo des rayons *',
          icon: Icons.shelves,
          photo: _rayonsPhoto,
          onTap: () {
            // TODO: Take/select photo
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fonctionnalité photo à implémenter'),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Photos complémentaires (optionnel)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Add additional photos
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fonctionnalité photo à implémenter'),
              ),
            );
          },
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Ajouter des photos'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_additionalPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_additionalPhotos.length} photo(s) ajoutée(s)',
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoButton({
    required String label,
    required IconData icon,
    required File? photo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo != null ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: photo != null ? Colors.green : Colors.grey,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: photo != null ? Colors.green : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              photo != null ? Icons.check_circle : Icons.camera_alt,
              color: photo != null ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommercialDataStep() {
    return Column(
      children: [
        const Text(
          'Potentiel du client',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
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
                        color: _potentiel == potentiel
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  selected: _potentiel == potentiel,
                  onSelected: (selected) {
                    setState(() {
                      _potentiel = selected ? potentiel : null;
                    });
                  },
                  selectedColor: Theme.of(context).primaryColor,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _frequenceVisite,
          decoration: InputDecoration(
            labelText: 'Fréquence de visite recommandée *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _frequences.map((freq) {
            return DropdownMenuItem(
              value: freq,
              child: Text(freq),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _frequenceVisite = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner une fréquence';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700]),
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
              const SizedBox(height: 8),
              const Text(
                '• L\'historique des visites sera disponible après la création\n'
                '• L\'historique des commandes sera disponible après la première commande',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
