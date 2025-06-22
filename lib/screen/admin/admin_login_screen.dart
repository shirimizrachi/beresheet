import 'package:flutter/material.dart';
import '../../config/admin_config.dart';
import '../../services/admin/admin_auth_service.dart';
import '../../model/admin/admin_user.dart';
import 'admin_dashboard_screen.dart';

/// Independent admin login screen for the admin panel system
/// Handles authentication against the home table in home schema
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check if user is already authenticated
  Future<void> _checkExistingSession() async {
    try {
      final isAuthenticated = await AdminAuthService.isAuthenticated();
      if (isAuthenticated && mounted) {
        _navigateToDashboard();
      }
    } catch (e) {
      print('Error checking existing admin session: $e');
    }
  }

  /// Handle login form submission
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final user = await AdminAuthService.login(email, password);
      
      if (user != null && mounted) {
        _navigateToDashboard();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to admin dashboard
  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const AdminDashboardScreen(),
      ),
    );
  }

  /// Validate email field
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!AdminConfig.isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate password field
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!AdminConfig.isValidPassword(value)) {
      return 'Password must be at least ${AdminConfig.minPasswordLength} characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminConfig.largePadding),
          child: Card(
            elevation: 8,
            borderOnForeground: false,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(AdminConfig.largePadding * 2),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 64,
                      color: Color(AdminConfig.primaryColorValue),
                    ),
                    const SizedBox(height: AdminConfig.defaultPadding),
                    
                    Text(
                      AdminConfig.adminLoginTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(AdminConfig.primaryColorValue),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AdminConfig.smallPadding),
                    
                    Text(
                      AdminConfig.adminAppTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AdminConfig.largePadding),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AdminConfig.defaultPadding),
                        decoration: BoxDecoration(
                          color: const Color(AdminConfig.errorColorValue).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(AdminConfig.errorColorValue),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(AdminConfig.errorColorValue),
                              size: 20,
                            ),
                            const SizedBox(width: AdminConfig.smallPadding),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(AdminConfig.errorColorValue),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AdminConfig.defaultPadding),
                    ],

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: AdminConfig.defaultPadding),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading,
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: AdminConfig.largePadding),

                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AdminConfig.primaryColorValue),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AdminConfig.defaultPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: AdminConfig.smallPadding),
                                Text('Signing in...'),
                              ],
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: AdminConfig.defaultPadding),

                    // Footer info
                    Text(
                      'Enter your admin credentials to access the tenant management system.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}