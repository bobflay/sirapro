import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'push_notification_service.dart';

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'user_data';

  static AuthService? _instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

  User? _cachedUser;

  AuthService._internal();

  factory AuthService() {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  /// Login with phone number (identifier) and password
  /// Returns the authenticated User on success
  /// Throws AuthException on failure
  Future<User> login(String identifier, String password) async {
    try {
      final response = await _apiService.post(
        '/api/login',
        body: {
          'identifier': identifier,
          'password': password,
        },
        includeAuth: false,
      );

      final status = response['status'] as bool? ?? false;
      if (!status) {
        throw AuthException(
            response['message'] as String? ?? 'Login failed');
      }

      final token = response['access_token'] as String?;
      if (token == null) {
        throw AuthException('Invalid response from server');
      }

      final userData = response['user'] as Map<String, dynamic>?;
      if (userData == null) {
        throw AuthException('Invalid response from server');
      }

      final user = User.fromJson(userData);

      // Store token securely
      await _secureStorage.write(key: _tokenKey, value: token);

      // Store user data in SharedPreferences for quick access
      await _saveUser(user);

      // Set token in API service for subsequent requests
      _apiService.setToken(token);

      // Cache user
      _cachedUser = user;

      // Send FCM token to server for push notifications
      await PushNotificationService().sendTokenToServer();

      return user;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw AuthException('Invalid phone number or password');
      }
      throw AuthException(e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Login failed. Please try again.');
    }
  }

  /// Logout the current user
  /// Clears all stored data
  Future<void> logout() async {
    try {
      // Try to call logout API (ignore errors - we'll clear local data anyway)
      final token = await getToken();
      if (token != null) {
        _apiService.setToken(token);

        // Delete FCM token from server before logout
        try {
          await PushNotificationService().deleteTokenFromServer();
        } catch (_) {
          // Ignore FCM token deletion errors
        }

        try {
          await _apiService.post('/api/logout');
        } catch (_) {
          // Ignore API errors during logout
        }
      }
    } finally {
      // Always clear local data
      await _clearAll();
    }
  }

  /// Check if user is logged in (has stored token)
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get stored access token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  /// Get current user (from cache or storage)
  Future<User?> getCurrentUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson == null) {
      return null;
    }

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _cachedUser = User.fromJson(userData);
      return _cachedUser;
    } catch (e) {
      return null;
    }
  }

  /// Validate stored token with the server
  /// Returns true if token is valid, false otherwise
  /// On invalid token, clears stored data
  Future<bool> validateToken() async {
    try {
      final token = await getToken();
      if (token == null) {
        return false;
      }

      _apiService.setToken(token);

      final response = await _apiService.get('/api/me');

      // Update cached user with fresh data
      if (response != null && response is Map<String, dynamic>) {
        final user = User.fromJson(response);
        await _saveUser(user);
        _cachedUser = user;
      }

      // Send FCM token to server (for returning users)
      await PushNotificationService().sendTokenToServer();

      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token is invalid, clear stored data
        await _clearAll();
      }
      return false;
    } catch (e) {
      // Network error - token might still be valid
      // Return true to allow offline access
      return await isLoggedIn();
    }
  }

  /// Change password
  /// Throws AuthException on failure with appropriate message
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw AuthException('You must be logged in to change password');
      }

      _apiService.setToken(token);

      final response = await _apiService.post(
        '/api/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );

      final status = response['status'] as bool? ?? false;
      if (!status) {
        throw AuthException(
            response['message'] as String? ?? 'Password change failed');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw AuthException('Current password is incorrect');
      } else if (e.statusCode == 422) {
        throw AuthException(e.message);
      }
      throw AuthException(e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to change password. Please try again.');
    }
  }

  /// Refresh user data from server
  Future<User?> refreshUserData() async {
    try {
      final token = await getToken();
      if (token == null) {
        return null;
      }

      _apiService.setToken(token);

      final response = await _apiService.get('/api/me');

      if (response != null && response is Map<String, dynamic>) {
        final user = User.fromJson(response);
        await _saveUser(user);
        _cachedUser = user;
        return user;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save user data to SharedPreferences
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Clear all stored authentication data
  Future<void> _clearAll() async {
    _cachedUser = null;
    _apiService.clearToken();

    await _secureStorage.delete(key: _tokenKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
