import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../home/main_wrapper.dart';

import 'verify_email_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        
        await _authService.signUpWithEmailAndPassword(email, password);

        if (!mounted) return;

        // Navigate to email verification instead of main wrapper
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(email: email),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        
        // Clean error message
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.signUpWithGoogle();
      
      if (!mounted) return;

      if (credential != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Strip "Exception: " from the message if present
      String errorMsg = e.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Welcome Texts
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.deepLavender,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Join FoundIT to start locating your items',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16, 
                        color: AppColors.dusk,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    _buildLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'John Doe',
                        prefixIcon: Icon(PhosphorIcons.user(), color: AppColors.dusk),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your full name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    _buildLabel('Email Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'student@university.edu',
                        prefixIcon: Icon(PhosphorIcons.envelopeSimple(), color: AppColors.dusk),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter an email address';
                        if (!value.contains('@')) return 'Please enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    _buildLabel('Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: '+60 123 456 789',
                        prefixIcon: Icon(PhosphorIcons.phone(), color: AppColors.dusk),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(PhosphorIcons.lockKey(), color: AppColors.dusk),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? PhosphorIcons.eyeClosed() : PhosphorIcons.eye(),
                            color: AppColors.dusk,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSignUp(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(PhosphorIcons.lockKey(), color: AppColors.dusk),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? PhosphorIcons.eyeClosed() : PhosphorIcons.eye(),
                            color: AppColors.dusk,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepLavender,
                        foregroundColor: AppColors.mist,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.mist)),
                            )
                          : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),

                    // OR Divider
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.silverShadow)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text("OR", style: TextStyle(color: AppColors.dusk.withOpacity(0.8), fontWeight: FontWeight.w500)),
                        ),
                        const Expanded(child: Divider(color: AppColors.silverShadow)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google Sign Up Button
                    OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.googleLogo(), size: 24),
                      label: const Text('Sign up with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepLavender,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.silverShadow),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleGoogleSignUp,
                    ),
                    const SizedBox(height: 32),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: AppColors.dusk),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Go back to login screen
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.deepLavender,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.deepLavender,
      ),
    );
  }
}
