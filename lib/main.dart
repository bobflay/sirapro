import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sirapro/firebase_options.dart';
import 'package:sirapro/screens/login_screen.dart';
import 'package:sirapro/screens/home_page.dart';
import 'package:sirapro/services/auth_service.dart';
import 'package:sirapro/services/data_sync_service.dart';
import 'package:sirapro/services/offline_queue_service.dart';
import 'package:sirapro/services/local_visit_report_service.dart';
import 'package:sirapro/services/visit_service.dart';
import 'package:sirapro/services/push_notification_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:sirapro/utils/app_scroll_behavior.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background message handler (mobile only - web uses service worker)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize push notifications
  await PushNotificationService().initialize();

  await initializeDateFormatting('fr_FR', null);
  // Load any active visit from persistent storage
  await VisitService().loadActiveVisit();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIRA PRO - Carré d\'Or',
      theme: AppTheme.lightTheme,
      scrollBehavior: AppScrollBehavior(),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final _authService = AuthService();
  final _visitService = VisitService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if user has a stored token
    final hasToken = await _authService.isLoggedIn();

    if (hasToken) {
      // Validate token with the server
      final isValid = await _authService.validateToken();

      if (isValid) {
        // Sync active visit state with server
        // This ensures the app bar shows the correct state
        await _visitService.syncWithServer();
      }

      if (mounted) {
        setState(() {
          _isLoggedIn = isValid;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Ne plus afficher automatiquement la page de permissions
    // Les permissions seront demandées quand l'utilisateur en a besoin
    return _isLoggedIn ? const StartupSyncScreen() : const LoginScreen();
  }
}

/// Écran de chargement au démarrage : envoie les saisies en attente puis
/// télécharge les données de travail (clients, catalogue, tournée…) avec une
/// barre de progression, pour que l'app soit utilisable hors ligne ensuite.
/// Sans réseau, l'écran est sauté immédiatement (données en cache).
class StartupSyncScreen extends StatefulWidget {
  const StartupSyncScreen({super.key});

  @override
  State<StartupSyncScreen> createState() => _StartupSyncScreenState();
}

class _StartupSyncScreenState extends State<StartupSyncScreen> {
  final _syncService = DataSyncService();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await OfflineQueueService().init();

    // Rattrape les rapports mis en file par une version antérieure de l'app :
    // sans copie locale, ils resteraient invisibles dans « Rapports de
    // visite » jusqu'à leur synchronisation.
    await LocalVisitReportService().backfillFromQueue();

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.any((r) => r != ConnectivityResult.none);

    if (online) {
      await _syncService.fullSync();
    }

    if (mounted) {
      setState(() {
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return const HomePage();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/logo.png', width: 140,
                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront,
                      size: 80, color: AppColors.primary)),
              const SizedBox(height: 40),
              ValueListenableBuilder<double>(
                valueListenable: _syncService.progress,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value == 0 ? null : value,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _syncService.currentStep,
                builder: (context, step, _) => Text(
                  step.isEmpty ? 'Préparation…' : step,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
