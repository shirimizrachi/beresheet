import 'package:flutter/material.dart';
import 'package:beresheet_app/utils/display_name_utils.dart';

class AppTheme {
  // Color scheme based on the provided design
  static const Color primaryColor = Color(0xFF1B5E5F);
  static const Color secondaryColor = Color(0xFFD4A574);
  static const Color accentColor = Colors.orange;
  static const Color backgroundColor = Color(0xFFF5F5F5);
  
  static const MaterialColor primarySwatch = MaterialColor(0xFF1B5E5F, {
    50: Color(0xFFE8F3F3),
    100: Color(0xFFC6E0E1),
    200: Color(0xFFA0CBCC),
    300: Color(0xFF7AB6B7),
    400: Color(0xFF5EA5A7),
    500: Color(0xFF1B5E5F),
    600: Color(0xFF175657),
    700: Color(0xFF134C4D),
    800: Color(0xFF0F4243),
    900: Color(0xFF083132),
  });

  static ThemeData get theme {
    return ThemeData(
      primarySwatch: primarySwatch,
      fontFamily: 'Heebo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        background: Colors.grey[50]!,
        surface: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.grey[50],
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      // Card theme
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class AppColors {
  static const Color primary = Color(0xFF1B5E5F);
  static const Color secondary = Color(0xFFD4A574);
  static const Color accent = Colors.orange;
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1B5E5F);
  static const Color textSecondary = Colors.grey;
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  
  // Activity type colors
  static const Color classActivity = Colors.blue;
  static const Color performanceActivity = Colors.purple;
  static const Color culturalActivity = Colors.orange;
  static const Color leisureActivity = Colors.green;
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static const TextStyle chipText = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppBorderRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double circular = 20.0;
}

class AppShadows {
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
  
  static final BoxShadow elevatedShadow = BoxShadow(
    color: Colors.black.withOpacity(0.15),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
}

class ActivityTypeHelper {
  static Color getColor(String type) {
    switch (type.toLowerCase()) {
      case 'event':
        return Colors.blue;
      case 'sport':
        return Colors.green;
      case 'cultural':
        return AppColors.culturalActivity;
      case 'art':
        return Colors.purple;
      case 'english':
        return Colors.orange;
      case 'religion':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
  
  static IconData getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'event':
        return Icons.event;
      case 'sport':
        return Icons.sports;
      case 'cultural':
        return Icons.palette;
      case 'art':
        return Icons.brush;
      case 'english':
        return Icons.language;
      case 'religion':
        return Icons.church;
      default:
        return Icons.event;
    }
  }
  
  static String getDisplayName(String type, [BuildContext? context]) {
    if (context != null) {
      return DisplayNameUtils.getEventTypeDisplayName(type, context);
    }
    // Fallback for when context is not available
    switch (type.toLowerCase()) {
      case 'event':
        return 'Event';
      case 'sport':
        return 'Sport';
      case 'cultural':
        return 'Cultural';
      case 'art':
        return 'Art';
      case 'english':
        return 'English';
      case 'religion':
        return 'Religion';
      default:
        return type.toUpperCase();
    }
  }
}