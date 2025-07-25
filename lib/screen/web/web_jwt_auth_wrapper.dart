import 'package:flutter/material.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/services/web/web_jwt_session_service.dart';
import 'package:beresheet_app/services/role_access_service.dart';
import 'package:beresheet_app/screen/web/web_jwt_login_screen.dart';
import 'package:beresheet_app/config/app_config.dart';
import 'dart:html' as html;

class WebJwtAuthWrapper extends StatefulWidget {
  final Widget child;
  final String? requiredRole;
  
  const WebJwtAuthWrapper({
    Key? key,
    required this.child,
    this.requiredRole,
  }) : super(key: key);

  @override
  State<WebJwtAuthWrapper> createState() => _WebJwtAuthWrapperState();
}

class _WebJwtAuthWrapperState extends State<WebJwtAuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _userRole;
  
  // Cache authentication state to avoid repeated checks
  static bool? _cachedAuthState;
  static String? _cachedUserRole;
  static DateTime? _lastAuthCheck;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      // Check if we have cached authentication data that's still valid
      final now = DateTime.now();
      if (_lastAuthCheck != null &&
          _cachedAuthState != null &&
          now.difference(_lastAuthCheck!).compareTo(_cacheTimeout) < 0) {
        // Use cached data
        if (mounted) {
          setState(() {
            _isAuthenticated = _cachedAuthState!;
            _userRole = _cachedUserRole;
            _isLoading = false;
          });
        }
        return;
      }
      
      // Perform fresh authentication check
      final isAuth = await WebJwtAuthService.isAuthenticated();
      
      if (isAuth) {
        final user = await WebJwtAuthService.getCurrentUser();
        
        // Cache the authentication state
        _cachedAuthState = true;
        _cachedUserRole = user?.role;
        _lastAuthCheck = now;
        
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _userRole = user?.role;
            _isLoading = false;
          });
        }
      } else {
        // Cache the unauthenticated state
        _cachedAuthState = false;
        _cachedUserRole = null;
        _lastAuthCheck = now;
        
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Log error only in debug mode
      assert(() {
        print('WebJwtAuthWrapper: Error checking authentication: $e');
        return true;
      }());
      
      // Don't cache error states
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLoginSuccess() async {
    // Clear cache on login success to force fresh check
    _clearAuthCache();
    await _checkAuthentication();
  }

  // Static method to clear authentication cache (call this on logout)
  static void _clearAuthCache() {
    _cachedAuthState = null;
    _cachedUserRole = null;
    _lastAuthCheck = null;
  }

  Future<void> _redirectToLogin() async {
    // Get the tenant from the stored home name
    final homeName = await WebJwtSessionService.getHomeName();
    final tenant = homeName ?? 'demo'; // default to demo if not found
    
    // Get the current URL origin
    final currentUrl = html.window.location.href;
    final uri = Uri.parse(currentUrl);
    
    // Navigate to the login page with the tenant prefix
    final loginUrl = '${uri.origin}/$tenant/login';
    html.window.location.href = loginUrl;
  }

  bool _hasRequiredRole() {
    if (widget.requiredRole == null) return true;
    if (_userRole == null) return false;
    
    // Check role hierarchy: manager > staff > service > resident
    // For tenant management and web features, only manager and staff are allowed
    switch (widget.requiredRole) {
      case 'manager':
        return _userRole == AppConfig.userRoleManager;
      case 'staff':
        return _userRole == AppConfig.userRoleManager || _userRole == AppConfig.userRoleStaff;
      case 'service':
        return _userRole == AppConfig.userRoleManager || _userRole == AppConfig.userRoleStaff || _userRole == AppConfig.userRoleService;
      case 'resident':
        return true; // All authenticated users can access resident-level content
      default:
        return true;
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

    if (!_isAuthenticated) {
      return WebJwtLoginScreen(
        onLoginSuccess: _handleLoginSuccess,
      );
    }

    if (!_hasRequiredRole()) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                _clearAuthCache();
                await WebJwtAuthService.logout();
                await _redirectToLogin();
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to access this page.\nOnly managers and staff can access tenant management features.\nYour role: ${_userRole ?? 'unknown'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  _clearAuthCache();
                  await WebJwtAuthService.logout();
                  await _redirectToLogin();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

// Convenience wrapper for pages that require authentication but no specific role
class WebJwtAuthenticatedPage extends StatelessWidget {
  final Widget child;
  
  const WebJwtAuthenticatedPage({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WebJwtAuthWrapper(
      child: child,
    );
  }
}

// Convenience wrapper for pages that require manager role
class WebJwtManagerPage extends StatelessWidget {
  final Widget child;
  
  const WebJwtManagerPage({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WebJwtAuthWrapper(
      requiredRole: 'manager',
      child: child,
    );
  }
}

// Convenience wrapper for pages that require staff role (manager or staff)
class WebJwtStaffPage extends StatelessWidget {
  final Widget child;
  
  const WebJwtStaffPage({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WebJwtAuthWrapper(
      requiredRole: 'staff',
      child: child,
    );
  }
}