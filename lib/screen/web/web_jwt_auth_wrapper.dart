import 'package:flutter/material.dart';
import 'package:beresheet_app/services/web/web_jwt_auth_service.dart';
import 'package:beresheet_app/screen/web/web_jwt_login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      print('WebJwtAuthWrapper: Starting authentication check...');
      final isAuth = await WebJwtAuthService.isAuthenticated();
      print('WebJwtAuthWrapper: isAuthenticated result: $isAuth');
      
      if (isAuth) {
        final user = await WebJwtAuthService.getCurrentUser();
        print('WebJwtAuthWrapper: Current user: ${user?.fullName} (${user?.role})');
        setState(() {
          _isAuthenticated = true;
          _userRole = user?.role;
          _isLoading = false;
        });
      } else {
        print('WebJwtAuthWrapper: User not authenticated, showing login screen');
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('WebJwtAuthWrapper: Error checking authentication: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLoginSuccess() async {
    await _checkAuthentication();
  }

  bool _hasRequiredRole() {
    if (widget.requiredRole == null) return true;
    if (_userRole == null) return false;
    
    // Check role hierarchy: manager > staff > service > resident
    switch (widget.requiredRole) {
      case 'manager':
        return _userRole == 'manager';
      case 'staff':
        return _userRole == 'manager' || _userRole == 'staff';
      case 'service':
        return _userRole == 'manager' || _userRole == 'staff' || _userRole == 'service';
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
                await WebJwtAuthService.logout();
                await _checkAuthentication();
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
                'You do not have permission to access this page.\nRequired role: ${widget.requiredRole ?? 'authenticated'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await WebJwtAuthService.logout();
                  await _checkAuthentication();
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