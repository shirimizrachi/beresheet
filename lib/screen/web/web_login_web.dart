import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import '../../config/app_config.dart';
import '../../services/web_auth_service.dart';

class WebLoginWeb extends StatefulWidget {
  const WebLoginWeb({Key? key}) : super(key: key);

  @override
  State<WebLoginWeb> createState() => _WebLoginWebState();
}

class _WebLoginWebState extends State<WebLoginWeb> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isCheckingSession = true;
  String? _errorMessage;
  int? _homeId;

  @override
  void initState() {
    super.initState();
    _extractHomeIdFromCookie();
    _checkExistingSession();
  }
  
  void _extractHomeIdFromCookie() {
    try {
      // Read the tenant_info cookie set by the server
      final cookieValue = html.document.cookie;
      if (cookieValue != null) {
        final cookies = cookieValue.split(';');
        for (final cookie in cookies) {
          final parts = cookie.trim().split('=');
          if (parts.length == 2 && parts[0] == 'tenant_info') {
            // Cookie format: "tenant_name:tenant_id"
            final tenantInfo = parts[1].split(':');
            if (tenantInfo.length == 2) {
              _homeId = int.tryParse(tenantInfo[1]);
              print('Extracted homeId from cookie: $_homeId (tenant: ${tenantInfo[0]})');
              return;
            }
          }
        }
      }
    } catch (e) {
      print('Error reading tenant cookie: $e');
    }
    
    // Fallback if cookie not found
    setState(() {
      _errorMessage = 'Could not determine tenant information. Please refresh the page.';
    });
  }

  Future<void> _checkExistingSession() async {
    // Initialize session from persistent storage
    await WebAuthService.initializeSession();
    
    // Check if user is already logged in
    if (WebAuthService.isLoggedIn) {
      // Navigate to management panel if already logged in
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/management');
        return;
      }
    }
    
    setState(() {
      _isCheckingSession = false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that we have homeId from cookie
    if (_homeId == null) {
      setState(() {
        _errorMessage = 'Could not determine tenant information. Please refresh the page.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await WebAuthService.loginWithHomeId(
        _phoneController.text.trim(),
        _passwordController.text,
        _homeId!,
      );

      if (result.success) {
        // Navigate to management panel
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/management');
        }
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking existing session
    if (_isCheckingSession) {
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Title
                const Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Beresheet Management Panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please login to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Help Text
                const Text(
                  'Note: Only users with manager role can access the management panel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simple session manager for web - now delegates to WebAuthService
class WebSessionManager {
  static final WebSessionManager _instance = WebSessionManager._internal();
  static WebSessionManager get instance => _instance;
  WebSessionManager._internal();

  Future<void> setSession(String sessionId, String userId, int homeId, String userRole, [String? userFullName]) async {
    await WebAuthService.setSession(sessionId, userId, homeId, userRole, userFullName);
  }

  Future<void> clearSession() async {
    await WebAuthService.clearSession();
  }

  bool get isLoggedIn => WebAuthService.isLoggedIn;
  String? get sessionId => WebAuthService.sessionId;
  String? get userId => WebAuthService.userId;
  int? get homeId => WebAuthService.homeId;
  String? get userRole => WebAuthService.userRole;
  String? get userFullName => WebAuthService.userFullName;
  bool get isManager => WebAuthService.isManager;
}