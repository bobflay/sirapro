import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sirapro/firebase_options.dart';
import 'package:sirapro/screens/login_screen.dart';
import 'package:sirapro/screens/home_page.dart';
import 'package:sirapro/services/auth_service.dart';
import 'package:sirapro/services/visit_service.dart';
import 'package:sirapro/services/push_notification_service.dart';
import 'package:sirapro/services/offline/offline_service.dart';
import 'package:sirapro/utils/app_colors.dart';
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

  // Initialize offline service (mobile only)
  if (!kIsWeb) {
    await OfflineService().initialize();
  }

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
    return _isLoggedIn ? const HomePage() : const LoginScreen();
  }
}
