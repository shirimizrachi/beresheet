import 'package:beresheet_app/screen/web/web_homepage.dart';
import 'package:beresheet_app/screen/web/web_management_panel.dart';
import 'package:beresheet_app/screen/web/web_jwt_login_screen.dart';
import 'package:beresheet_app/screen/web/web_jwt_auth_wrapper.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize web JWT auth service to restore sessions
  await WebJwtAuthService.initialize();
  
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
      
      routerDelegate: _TenantRouterDelegate(),
      routeInformationParser: _TenantRouteInformationParser(),
    );
  }
}

class _TenantRouteInformationParser extends RouteInformationParser<String> {
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
    
    // Handle empty path
    if (path.isEmpty) {
      return '';
    }
    
    return path;
  }

  @override
  RouteInformation restoreRouteInformation(String path) {
    return RouteInformation(location: '/#$path');
  }
}

class _TenantRouterDelegate extends RouterDelegate<String> with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
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
    // Check if user is logged in for all pages except login
    // Note: We'll use a FutureBuilder for async JWT check in the actual screens
    return _buildPageContent(path);
  }

  Widget _buildPageContent(String path) {
    
    switch (path) {
      case 'login':
        return const WebJwtLoginScreen();
      
      // Management routes - require staff role (manager, staff, or instructor)
      case 'manage':
      case 'manage/':
        return const WebJwtStaffPage(
          child: WebManagementPanel(initialTab: 'home'),
        );
      case 'manage/events':
        return const WebJwtStaffPage(
          child: WebManagementPanel(initialTab: 'events'),
        );
      case 'manage/users':
        return const WebJwtManagerPage(
          child: WebManagementPanel(initialTab: 'user_list'),
        );
      
      // Public homepage with events carousel - require authentication but accessible to all roles
      case 'home':
      case '':
      default:
        return const WebJwtAuthenticatedPage(
          child: WebHomePage(),
        );
    }
  }

  @override
  Future<void> setNewRoutePath(String path) async {
    _currentPath = path;
    notifyListeners();
  }
}