import 'package:flutter/material.dart';
import 'package:sirapro/screens/login_screen.dart';
import 'package:sirapro/screens/home_page.dart';
import 'package:sirapro/services/auth_service.dart';
import 'package:sirapro/services/visit_service.dart';
import 'package:sirapro/utils/app_colors.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
