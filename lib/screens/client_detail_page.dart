import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/models/alert.dart';
import 'package:sirapro/services/alert_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/visit.dart';
import '../models/visit_report.dart';
import '../models/order.dart';
import '../data/mock_visit_reports.dart';
import 'visit_report_page.dart';
import 'visit_report_detail_page.dart';
import 'order_creation_page.dart';

class ClientDetailPage extends StatefulWidget {
  final Client client;

  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late Client _client;
  bool _isEditing = false;

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
  String? _selectedZone;
  String? _selectedPotentiel;
  String? _selectedFrequence;

  final _formKey = GlobalKey<FormState>();

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
  void initState() {
    super.initState();
    _client = widget.client;
    _initControllers();
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
    _selectedZone = _client.zone;
    _selectedPotentiel = _client.potentiel;
    _selectedFrequence = _client.frequenceVisite;
  }

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
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // Cancel editing - reset controllers
        _initControllers();
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Simulate save
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading

      // Create updated client
      final updatedClient = _client.copyWith(
        boutiqueName: _boutiqueNameController.text.trim(),
        type: _selectedType,
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
        potentiel: _selectedPotentiel,
        frequenceVisite: _selectedFrequence,
      );

      setState(() {
        _client = updatedClient;
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _makePhoneCall(String phoneNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel vers $phoneNumber'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _openWhatsApp(String phoneNumber) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouvrir WhatsApp: $phoneNumber'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  void _sendEmail(String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email vers $email'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    // Build the Google Maps URL
    String mapsUrl;
    if (_client.gpsLocation != null) {
      // Parse GPS coordinates (format: "5.3600° N, 4.0083° W")
      final coords = _client.gpsLocation!
          .replaceAll('°', '')
          .replaceAll(' N', '')
          .replaceAll(' S', '')
          .replaceAll(' E', '')
          .replaceAll(' W', '')
          .split(',');
      if (coords.length == 2) {
        final lat = coords[0].trim();
        final lng = coords[1].trim();
        // Try native Google Maps app first, fallback to web
        mapsUrl = 'google.navigation:q=$lat,$lng';
        final Uri mapsUri = Uri.parse(mapsUrl);

        // Try launching with Google Maps app
        if (await canLaunchUrl(mapsUri)) {
          await launchUrl(mapsUri);
        } else {
          // Fallback to web URL
          final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
        return;
      }
    }

    // Fallback to address-based search
    final address = Uri.encodeComponent(
      '${_client.address}, ${_client.quartier}, ${_client.ville}, Côte d\'Ivoire',
    );
    final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');

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
                  markerId: MarkerId(_client.id),
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

  Future<void> _activateClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activer le client'),
        content: Text(
          'Voulez-vous activer "${_client.boutiqueName}" ?',
        ),
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
            child: const Text('Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _client = _client.copyWith(status: 'Actif', isActive: true);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client activé'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
        Navigator.pop(context, _client);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(_isEditing ? 'Modifier Client' : 'Détails Client'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _client),
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
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(_client.type),
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  _client.boutiqueName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Type
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _client.type,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Status and Potentiel
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _client.isActive ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _client.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_client.potentiel != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
                    onTap: () => _makePhoneCall(_client.phone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: _client.whatsapp != null
                        ? () => _openWhatsApp(_client.whatsapp!)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.blue,
                    onTap: _client.email != null
                        ? () => _sendEmail(_client.email!)
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions Section
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
                  _buildInfoRow(Icons.map, 'Quartier', _client.quartier),
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
                  if (_client.potentiel != null)
                    _buildInfoRow(Icons.star, 'Potentiel', _client.potentiel!),
                  if (_client.frequenceVisite != null)
                    _buildInfoRow(
                      Icons.schedule,
                      'Fréquence de visite',
                      _client.frequenceVisite!,
                    ),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Client depuis',
                    _formatDate(_client.createdAt),
                  ),
                ]),

                const SizedBox(height: 20),

                // Activate button if client is pending
                if (!_client.isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _activateClient,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Activer ce client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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
              label: 'Téléphone *',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le numéro de téléphone';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.chat,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionButton(
            icon: Icons.assignment,
            label: 'Rapport\nde visite',
            color: Colors.blue,
            onTap: _createVisitReport,
          ),
          _buildQuickActionButton(
            icon: Icons.shopping_cart,
            label: 'Passer\ncommande',
            color: Colors.green,
            onTap: _createOrder,
          ),
          _buildQuickActionButton(
            icon: Icons.warning_amber,
            label: 'Créer\nalerte',
            color: Colors.orange,
            onTap: _createAlert,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
    );
  }

  void _createVisitReport() {
    // Get previous reports for this client
    final previousReports = getVisitReportsByClient(_client.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
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
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToNewVisitReport();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau Rapport de Visite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(),

            // Previous Reports List
            Expanded(
              child: previousReports.isEmpty
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
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: previousReports.length,
                      itemBuilder: (context, index) {
                        final report = previousReports[index];
                        return _buildVisitReportCard(report);
                      },
                    ),
            ),
          ],
        ),
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
        onTap: () => _viewVisitReportDetails(report),
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
                    if (report.facadePhoto != null || report.shelfPhoto != null) ...[
                      const SizedBox(height: 8),
                      _buildReportInfoRow(
                        Icons.photo_camera,
                        'Photos',
                        '${[report.facadePhoto, report.shelfPhoto, ...report.additionalPhotos].where((p) => p != null).length} photo(s)',
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
    // Create a visit for this specific client
    final visit = Visit(
      id: 'visit-${DateTime.now().millisecondsSinceEpoch}',
      routeId: 'ad-hoc-visit',
      clientId: _client.id,
      clientName: _client.boutiqueName,
      clientAddress: _client.fullAddress,
      order: 1,
      latitude: _parseLatitude(_client.gpsLocation),
      longitude: _parseLongitude(_client.gpsLocation),
      status: VisitStatus.inProgress,
      actualStartTime: DateTime.now(),
      createdAt: DateTime.now(),
    );

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
    // Navigate to order creation page
    final Order? order = await Navigator.push<Order>(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCreationPage(
          client: _client,
          visit: null, // No visit context when creating from client detail
        ),
      ),
    );

    if (order != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commande créée avec succès: ${order.formattedTotal}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _createAlert() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    AlertType selectedType = AlertType.other;
    AlertPriority selectedPriority = AlertPriority.medium;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
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
                Text(
                  'Client : ${_client.boutiqueName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                titleController.dispose();
                descriptionController.dispose();
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
        id: AlertService().generateAlertId(),
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        type: selectedType,
        priority: selectedPriority,
        clientId: _client.id,
        clientName: _client.boutiqueName,
        createdAt: DateTime.now(),
      );

      final success = await AlertService().createAlert(alert);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alerte "${alert.title}" créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
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
}
