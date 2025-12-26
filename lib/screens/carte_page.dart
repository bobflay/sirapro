import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sirapro/models/client.dart';
import 'package:sirapro/services/client_service.dart';
import 'package:sirapro/screens/client_detail_page.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/widgets/session_aware_app_bar.dart';

class CartePage extends StatefulWidget {
  const CartePage({super.key});

  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  final ClientService _clientService = ClientService();
  final Completer<GoogleMapController> _mapController = Completer();

  bool _isLoading = true;
  bool _isLoadingClients = false;
  String? _errorMessage;
  Position? _currentPosition;
  List<Client> _clients = [];
  Set<Marker> _markers = {};
  Client? _selectedClient;
  Timer? _debounceTimer;

  // Default position (Abidjan, Côte d'Ivoire)
  static const LatLng _defaultPosition = LatLng(5.3600, -4.0083);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _getCurrentLocation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors du chargement: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadClientsInBounds(LatLngBounds bounds) async {
    if (_isLoadingClients) return;

    setState(() {
      _isLoadingClients = true;
    });

    try {
      final response = await _clientService.getClients(
        limit: 100,
        mapNorth: bounds.northeast.latitude,
        mapSouth: bounds.southwest.latitude,
        mapEast: bounds.northeast.longitude,
        mapWest: bounds.southwest.longitude,
      );

      if (mounted) {
        setState(() {
          _clients = response.clients.where((c) => c.hasLocation).toList();
          _isLoadingClients = false;
        });
        _buildMarkers();
      }
    } catch (e) {
      debugPrint('Error loading clients: $e');
      if (mounted) {
        setState(() {
          _isLoadingClients = false;
        });
      }
    }
  }

  void _onCameraIdle() async {
    if (!_mapController.isCompleted) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final controller = await _mapController.future;
      final bounds = await controller.getVisibleRegion();
      _loadClientsInBounds(bounds);
    });
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};

    // Add client markers
    for (final client in _clients) {
      if (client.latitude != null && client.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId('client_${client.id}'),
            position: LatLng(client.latitude!, client.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              client.hasOpenAlert ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
            ),
            onTap: () => _onClientMarkerTapped(client),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  void _onClientMarkerTapped(Client client) {
    setState(() {
      _selectedClient = client;
    });
  }

  void _closeClientCard() {
    setState(() {
      _selectedClient = null;
    });
  }

  Future<void> _centerOnUserLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position non disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        19,
      ),
    );
  }

  LatLng _getInitialPosition() {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _defaultPosition;
  }

  Widget _buildClientCard(Client client) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.store,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.type,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _closeClientCard,
                color: Colors.grey[600],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  client.fullAddress,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (client.hasOpenAlert) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 14, color: Colors.orange[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Alerte en cours',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientDetailPage(client: client),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Voir les détails'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Chargement de la carte...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Une erreur est survenue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeMap,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: SessionAwareAppBar(
        title: 'Carte des Clients',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onCameraIdle,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _errorMessage != null
              ? _buildErrorWidget()
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _getInitialPosition(),
                        zoom: 19,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (controller) {
                        _mapController.complete(controller);
                        // Load clients for initial visible region
                        Future.delayed(const Duration(milliseconds: 500), () {
                          _onCameraIdle();
                        });
                      },
                      onCameraIdle: _onCameraIdle,
                      onTap: (_) => _closeClientCard(),
                    ),
                    // Client count badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoadingClients)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Icon(
                                Icons.store,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              '${_clients.length} clients',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Center on user location button
                    Positioned(
                      bottom: _selectedClient != null ? 220 : 24,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        onPressed: _centerOnUserLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    // Selected client card
                    if (_selectedClient != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildClientCard(_selectedClient!),
                      ),
                  ],
                ),
    );
  }
}
