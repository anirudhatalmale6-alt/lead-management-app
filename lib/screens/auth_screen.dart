import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onLogin});

  /// Called after a successful sign-in with the resolved [AppUser].
  final void Function(AppUser user) onLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Toggle mode
  // ---------------------------------------------------------------------------

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _animController.reset();
    _animController.forward();
  }

  // ---------------------------------------------------------------------------
  // Sign In
  // ---------------------------------------------------------------------------

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Attempt to fetch the Firestore user document.
      AppUser? appUser;
      try {
        appUser = await _authService.getCurrentAppUser();
      } catch (_) {
        // Firestore rules may block read — fall through to fallback.
      }

      // Fallback: if no Firestore document exists (demo / first-time setup),
      // create a basic AppUser with admin role so the app remains usable.
      appUser ??= AppUser(
        uid: credential.user!.uid,
        name: credential.user!.displayName ??
            _emailController.text.trim().split('@').first,
        email: credential.user!.email ?? _emailController.text.trim(),
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        widget.onLogin(appUser);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(_parseAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Up
  // ---------------------------------------------------------------------------

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Create the Firestore user document.
      try {
        await _authService.createUserDocument(
          credential.user!.uid,
          _emailController.text.trim(),
          _displayNameController.text.trim(),
          UserRole.admin,
        );
      } catch (_) {
        // Firestore rules may block write — continue with fallback.
      }

      // Fetch the newly created document.
      AppUser? appUser;
      try {
        appUser = await _authService.getCurrentAppUser();
      } catch (_) {
        // Firestore rules may block read — fall through to fallback.
      }

      // Fallback
      appUser ??= AppUser(
        uid: credential.user!.uid,
        name: _displayNameController.text.trim(),
        email: _emailController.text.trim(),
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );

      if (mounted) {
        widget.onLogin(appUser);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(_parseAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Forgot Password
  // ---------------------------------------------------------------------------

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address first.');
      return;
    }

    try {
      await _authService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      _showError(_parseAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Error helpers
  // ---------------------------------------------------------------------------

  String _parseAuthError(Object error) {
    final msg = error.toString();
    // Firebase Auth exceptions contain useful messages after the bracket.
    if (msg.contains('] ')) {
      return msg.split('] ').last;
    }
    return msg;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // deep indigo
              Color(0xFF1565C0), // blue
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Card(
                elevation: 8,
                shadowColor: Colors.black38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 36.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // -- Icon --
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.leaderboard_rounded,
                              size: 38,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // -- Title --
                          Text(
                            'Lead Management System',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignUp
                                ? 'Create a new admin account'
                                : 'Sign in to continue',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // -- Display Name (Sign Up only) --
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _displayNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Display Name',
                                prefixIcon: const Icon(Icons.person_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (_isSignUp &&
                                    (v == null || v.trim().isEmpty)) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // -- Email --
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!v.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // -- Password --
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: _isSignUp ? null : const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your password';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // -- Confirm Password (Sign Up only) --
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: null,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon:
                                    const Icon(Icons.lock_reset_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (_isSignUp) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // -- Forgot Password (Sign In only) --
                          if (!_isSignUp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _isLoading ? null : _handleForgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),

                          // -- Submit Button --
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_isSignUp
                                      ? _handleSignUp
                                      : _handleSignIn),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'Sign Up' : 'Sign In',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // -- Toggle Sign In / Sign Up --
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUp
                                    ? 'Already have an account?'
                                    : 'Need an admin account?',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading ? null : _toggleMode,
                                child: Text(
                                  _isSignUp ? 'Sign In' : 'Sign Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
