import 'package:beresheet_app/screen/web/web_homepage.dart';
import 'package:beresheet_app/screen/web/web_management_panel.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: WebApp()));
}

class WebApp extends StatelessWidget {
  const WebApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'בראשית - קהילת מגורים',
      theme: AppTheme.theme,
      
      // Flutter's official internationalization setup
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConfig.supportedLocales,
      locale: AppConfig.appLocale,
      
      // Locale resolution callback
      localeResolutionCallback: (locale, supportedLocales) {
        // Check if the current device locale is supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // If not supported, return the first supported locale (Hebrew)
        return supportedLocales.first;
      },
      
      builder: (context, child) {
        return Directionality(
          textDirection: AppConfig.textDirection,
          child: child ?? const SizedBox(),
        );
      },
      
      routerDelegate: _AppRouterDelegate(),
      routeInformationParser: _AppRouteInformationParser(),
    );
  }
}

class _AppRouteInformationParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async {
    final uri = Uri.parse(routeInformation.location ?? '/');
    
    // Handle both regular paths and hash fragments
    String path = uri.path;
    if (uri.fragment.isNotEmpty) {
      path = uri.fragment;
    }
    
    // Clean up the path
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    return path.isEmpty ? 'home' : path;
  }

  @override
  RouteInformation restoreRouteInformation(String path) {
    return RouteInformation(location: '/#$path');
  }
}

class _AppRouterDelegate extends RouterDelegate<String> with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  String _currentPath = 'home';
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  String get currentConfiguration => _currentPath;

  // Public method to navigate to different routes
  void navigateTo(String path) {
    _currentPath = path;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          child: _buildPage(_currentPath),
          key: ValueKey(_currentPath),
        ),
      ],
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        _currentPath = 'home';
        notifyListeners();
        return true;
      },
    );
  }

  Widget _buildPage(String path) {
    switch (path) {
      case 'manage':
        return const WebManagementPanel();
      case 'home':
      default:
        return const WebHomePage();
    }
  }

  @override
  Future<void> setNewRoutePath(String path) async {
    _currentPath = path;
    notifyListeners();
  }
}