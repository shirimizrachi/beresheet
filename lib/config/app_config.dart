import 'package:flutter/material.dart';

/// Application configuration constants
class AppConfig {
  /// Default language for the application - Hebrew
  static const String defaultLanguage = 'he';
  
  /// Fallback language if default fails to load - English
  static const String fallbackLanguage = 'en';
  
  /// List of supported languages
  static const List<String> supportedLanguages = ['he', 'en'];
  
  /// Default text direction - RTL for Hebrew-first app
  static const TextDirection textDirection = TextDirection.rtl;
  
  /// Check if the app is using RTL direction
  static bool get isRTL => textDirection == TextDirection.rtl;
  
  /// Check if the app is using LTR direction
  static bool get isLTR => textDirection == TextDirection.ltr;
  
  /// Get the text direction as a string
  static String get directionString => isRTL ? 'RTL' : 'LTR';
  
  /// Default locale - Hebrew (Israel)
  static const Locale appLocale = Locale('he', 'IL');
  
  /// English locale for fallback
  static const Locale englishLocale = Locale('en', 'US');
  
  /// Get supported locales
  static List<Locale> get supportedLocales => [
    appLocale,      // Hebrew first (default)
    englishLocale,  // English as fallback
  ];
  
  /// Get locale from language code
  static Locale getLocale(String languageCode) {
    switch (languageCode) {
      case 'he':
        return appLocale;
      case 'en':
        return englishLocale;
      default:
        return appLocale; // Default to Hebrew
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
        return TextDirection.rtl; // Default to RTL
    }
  }
}