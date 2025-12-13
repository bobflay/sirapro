import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

/// Page pour demander les permissions au premier lancement
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _isChecking = false;
  Map<String, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    // Ne vérifier que l'état initial, ne pas afficher les résultats
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final locationStatus = await Permission.locationWhenInUse.status;

    print('🔍 Vérification initiale de la permission de localisation:');
    print('   Location: $locationStatus');

    // Ne mettre à jour l'état que si la permission est déjà accordée
    if (locationStatus.isGranted) {
      setState(() {
        _permissionStatuses = {
          'location': locationStatus,
        };
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isChecking = true;
    });

    print('📋 Demande de la permission de localisation...');

    try {
      var locationStatus = await Permission.locationWhenInUse.status;

      print('État actuel de la localisation: $locationStatus');

      // Demander la permission de localisation via Geolocator
      if (!locationStatus.isGranted && !locationStatus.isPermanentlyDenied) {
        print('📍 Demande permission localisation...');
        try {
          final permission = await Geolocator.requestPermission();
          print('   Résultat Geolocator: $permission');
          locationStatus = await Permission.locationWhenInUse.status;
        } catch (e) {
          print('   Erreur Geolocator: $e');
        }
      }

      // Vérification finale
      locationStatus = await Permission.locationWhenInUse.status;

      print('📊 Résultat final - Localisation: $locationStatus');

      setState(() {
        _permissionStatuses = {
          'location': locationStatus,
        };
        _isChecking = false;
      });

      // Si la permission est accordée, continuer
      if (locationStatus.isGranted) {
        print('✅ Permission de localisation accordée');
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        print('❌ Permission de localisation non accordée');
      }
    } catch (e) {
      print('❌ Erreur lors de la demande de permission: $e');
      setState(() {
        _isChecking = false;
      });
    }
  }

  bool get _allPermissionsGranted {
    final locationGranted = _permissionStatuses['location']?.isGranted == true;
    return locationGranted;
  }

  bool get _somePermissionsPermanentlyDenied {
    return _permissionStatuses['location']?.isPermanentlyDenied == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
              // Icône
              Icon(
                Icons.security,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Titre
              const Text(
                'Permissions requises',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                _somePermissionsPermanentlyDenied
                    ? 'La permission de localisation a été refusée. Veuillez l\'activer dans les paramètres.'
                    : 'SIRA PRO a besoin d\'accéder à votre localisation pour géolocaliser vos visites clients.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),

              // Permission de localisation
              _buildPermissionItem(
                icon: Icons.location_on,
                title: 'Localisation',
                description: 'Pour géolocaliser vos visites clients et enregistrer la position GPS',
                status: _permissionStatuses['location'],
              ),
              const SizedBox(height: 16),

              // Note sur les autres permissions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Les permissions caméra et photos vous seront demandées quand vous en aurez besoin.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Message d'avertissement si permissions refusées de manière permanente
              if (_somePermissionsPermanentlyDenied) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Permissions refusées',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Certaines permissions ont été refusées. Veuillez les activer dans les paramètres de votre appareil.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Boutons d'action
              if (!_allPermissionsGranted) ...[
                if (_somePermissionsPermanentlyDenied)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Ouvrir les paramètres'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isChecking ? null : _requestPermissions,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      _isChecking
                          ? 'Vérification...'
                          : 'Autoriser les permissions',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Bouton "Plus tard"
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Plus tard'),
                ),
              ] else ...[
                // Permissions accordées - Bouton Continuer
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Continuer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Note de confidentialité
              const Text(
                'Ces permissions sont uniquement utilisées pour les fonctionnalités de l\'application. Vos données restent confidentielles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),

              // Note pour le développement
              if (_somePermissionsPermanentlyDenied) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Pour réinitialiser les permissions pendant le développement :\n'
                    '1. Désinstallez l\'application\n'
                    '2. Réinstallez-la depuis Xcode/Android Studio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    PermissionStatus? status,
  }) {
    Color iconColor = Colors.grey;
    Color statusColor = Colors.grey;
    String statusText = 'Non demandée';
    IconData? statusIcon;

    if (status != null) {
      if (status.isGranted) {
        iconColor = Colors.green;
        statusColor = Colors.green;
        statusText = 'Accordée';
        statusIcon = Icons.check_circle;
      } else if (status.isPermanentlyDenied) {
        iconColor = Colors.red;
        statusColor = Colors.red;
        statusText = 'Refusée définitivement';
        statusIcon = Icons.cancel;
      } else if (status.isDenied) {
        // Sur iOS, isDenied peut signifier "jamais demandée" ou "refusée"
        // On affiche "Non demandée" par défaut
        iconColor = Colors.grey;
        statusColor = Colors.grey;
        statusText = 'Non demandée';
        // Pas d'icône pour ne pas confondre avec une vraie refus
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (statusIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(statusIcon, size: 16, color: statusColor),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
