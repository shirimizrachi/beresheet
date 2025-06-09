import 'package:flutter/material.dart';

/// Application configuration constants
class AppConfig {
  /// Text direction for the entire application
  /// Set to TextDirection.rtl for Hebrew/Arabic support
  /// Set to TextDirection.ltr for English/Latin languages
  static const TextDirection textDirection = TextDirection.rtl;
  
  /// Default language for the application
  static const String defaultLanguage = 'he'; // Hebrew as default
  
  /// Fallback language if default fails to load
  static const String fallbackLanguage = 'en'; // English as fallback
  
  /// List of supported languages
  static const List<String> supportedLanguages = ['he', 'en'];
  
  /// Check if the app is using RTL direction
  static bool get isRTL => textDirection == TextDirection.rtl;
  
  /// Check if the app is using LTR direction
  static bool get isLTR => textDirection == TextDirection.ltr;
  
  /// Get the text direction as a string
  static String get directionString => isRTL ? 'RTL' : 'LTR';
  
  /// Application title
  static const String appTitle = 'בראשית - קהילת מגורים';
  
  /// Locale for the application (optional, for internationalization)
  static const Locale appLocale = Locale('he', 'IL'); // Hebrew - Israel
  
  /// Alternative locale for LTR (if needed in future)
  static const Locale altLocale = Locale('en', 'US'); // English - US
  
  /// Get locale from language code
  static Locale getLocale(String languageCode) {
    switch (languageCode) {
      case 'he':
        return appLocale;
      case 'en':
        return altLocale;
      default:
        return appLocale;
    }
  }
  
  /// Get text direction from language code
  static TextDirection getTextDirection(String languageCode) {
    switch (languageCode) {
      case 'he':
        return TextDirection.rtl;
      case 'en':
        return TextDirection.ltr;
      default:
        return textDirection;
    }
  }
}