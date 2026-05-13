import 'package:flutter/material.dart';

// Colori dell'app
class AppColors {
  // Colore principale - Blu principale
  static const Color primary = Color(0xFF000099);

  // Colore secondario - Giallo
  static const Color secondary = Color(0xFFFFFF00);

  // Blu secondario
  static const Color secondaryBlue = Color(0xFF005BCD);

  // Grigio scrittura
  static const Color textGray = Color(0xFF333333);

  // Altri colori utili
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF8F9FA);
  static const Color error = Color(0xFFFF5722);
  static const Color success = Color(0xFF4CAF50);

  /// Tonalità media tra [primary] e [secondaryBlue] (stessa palette del drawer).
  static const Color loggedInBackground = Color(0xFF002DB3);

  /// Stesso gradiente del menu laterale, per sfondi a tutta pagina dopo il login.
  static const LinearGradient loggedInBackgroundGradient = LinearGradient(
    colors: [primary, secondaryBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Azzurro pulsanti servizi (gradiente: un filo più scuro del celeste chiaro, senza appesantire).
  static const Color serviceButtonAzure = Color(0xFF52A8E8);
  static const Color serviceButtonAzureEnd = Color(0xFF74BAEE);

  static const LinearGradient serviceButtonGradient = LinearGradient(
    colors: [serviceButtonAzure, serviceButtonAzureEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sfondo condiviso per pulsanti servizio e «Invia» (gradiente + ombra leggera).
  static BoxDecoration serviceButtonBoxDecoration({double radius = 20}) {
    return BoxDecoration(
      gradient: serviceButtonGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: serviceButtonAzure.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// Tema dell'app
class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      useMaterial3: true,
      fontFamily: 'Karla',
      textTheme: const TextTheme(
        // Titoli grandi
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontFamily: 'Karla',
        ),
        // Titoli medi
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontFamily: 'Karla',
        ),
        // Titoli piccoli
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textGray,
          fontFamily: 'Karla',
        ),
        // Testo corpo
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textGray,
          fontFamily: 'Karla',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.textGray,
          fontFamily: 'Karla',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.textGray,
          fontFamily: 'Karla',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontFamily: 'Karla',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black54,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Karla',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textGray,
          fontFamily: 'Karla',
        ),
      ),
    );
  }
}
