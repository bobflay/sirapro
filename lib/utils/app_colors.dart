import 'package:flutter/material.dart';

/// Carré d'Or Brand Colors
/// Strict color palette from the Carré d'Or logo
class AppColors {
  // === LOGO COLORS (PRIMARY USE) ===
  static const Color primary = Color(0xFFE30613); // Carré d'Or Red
  static const Color secondary = Color(0xFFFDB813); // Carré d'Or Gold
  static const Color accent = Color(0xFF1A1A1A); // Logo Black

  // === SHADES OF LOGO RED ===
  static const Color primaryLight = Color(0xFFFF3B47); // Lighter red
  static const Color primaryDark = Color(0xFFB00510); // Darker red
  static const Color primaryVeryLight = Color(0xFFFFE5E7); // Very light red for backgrounds

  // === SHADES OF LOGO GOLD ===
  static const Color secondaryLight = Color(0xFFFFC940); // Lighter gold
  static const Color secondaryDark = Color(0xFFC89B0E); // Darker gold
  static const Color secondaryVeryLight = Color(0xFFFFF9E6); // Very light gold for backgrounds

  // === NEUTRAL COLORS (ESSENTIAL) ===
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color background = Color(0xFFF8F8F8); // Subtle gray background
  static const Color lightGray = Color(0xFFE5E5E5);
  static const Color gray = Color(0xFF999999);
  static const Color darkGray = Color(0xFF555555);

  // === ONE ADDITIONAL COLOR (SUCCESS GREEN ONLY) ===
  static const Color success = Color(0xFF2D7A2E); // Dark green for success states only

  // === ALL STATUSES USE LOGO COLORS ===
  // Alert Priorities - using logo colors
  static const Color urgent = primaryDark; // Dark red
  static const Color high = primary; // Brand red
  static const Color medium = secondary; // Gold
  static const Color low = gray; // Gray

  // Order/Status - using logo colors
  static const Color pending = secondary; // Gold for pending
  static const Color confirmed = primaryDark; // Dark red for confirmed
  static const Color processing = primary; // Red for processing
  static const Color delivered = success; // Green for delivered (only use of green)
  static const Color cancelled = gray; // Gray for cancelled

  // Visit Reports - using logo colors
  static const Color visitActive = primary; // Red for active
  static const Color visitCompleted = success; // Green for completed
  static const Color visitIncomplete = secondary; // Gold for incomplete

  // Legacy aliases (map to logo colors)
  static const Color error = primary; // Red
  static const Color warning = secondary; // Gold
  static const Color info = accent; // Black

  // Gradient combinations using brand colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE30613), Color(0xFFB00510)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFFDB813), Color(0xFFC89B0E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFE30613), Color(0xFFFDB813)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Helper methods
  static Color getAlertPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return urgent;
      case 'high':
        return high;
      case 'medium':
        return medium;
      case 'low':
        return low;
      default:
        return gray;
    }
  }

  static Color getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return pending;
      case 'confirmed':
        return confirmed;
      case 'processing':
        return processing;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      default:
        return gray;
    }
  }
}

/// Material Theme using Carré d'Or brand colors
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.white,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.black,
        onError: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: AppColors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        filled: true,
        fillColor: AppColors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGray,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.black),
        secondaryLabelStyle: const TextStyle(color: AppColors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.white,
        unselectedLabelColor: Color(0x80FFFFFF),
        indicatorColor: AppColors.white,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.secondary,
        textColor: AppColors.black,
      ),
    );
  }
}
