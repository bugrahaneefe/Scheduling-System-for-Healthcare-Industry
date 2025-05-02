// lib/views/login_view.dart

import 'package:flutter/material.dart';
import 'package:project491/components/custom_button.dart';
import 'package:project491/managers/auth_services.dart';
import 'package:project491/views/reset_password_view.dart';
import 'package:project491/views/room_invitation_view.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'signup_view.dart';
import 'package:flutter/services.dart';
import 'home_view.dart';
import 'dart:async';

class LoginView extends StatefulWidget {
  final String? pendingRoomId;

  const LoginView({Key? key, this.pendingRoomId}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _showErrorPopup = false;
  bool _isSuccess = false;
  bool _isLoading = false; // Add this line after other state variables
  Timer? _errorTimer;
  Timer? _successTimer;

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
      _isSuccess = false;
    });
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showErrorPopup = false;
      });
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
      _isSuccess = true;
    });
    _successTimer?.cancel();
    _successTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showErrorPopup = false;
        _isSuccess = false;
      });
    });
  }

  Future<void> _handleSuccessfulLogin(BuildContext context) async {
    if (widget.pendingRoomId != null) {
      // Navigate to room invitation if there's a pending room
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) => RoomInvitationView(
                  roomId: widget.pendingRoomId!,
                  returnToHome: true, // Add this parameter
                ),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } else {
      // Navigate to home view as usual
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeView()),
          (route) => false, // Remove all previous routes
        );
      }
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      resizeToAvoidBottomInset: true, // Add this line
      appBar: AppBar(
        title: null, // Removed the title
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          // Wrap with SingleChildScrollView
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Calendar icon
                      const Icon(
                        Icons.calendar_today,
                        size: 48,
                        color: Color(0xFF375DFB),
                      ),
                      const SizedBox(height: 20),
                      // "Sign in to your Account" text
                      const Text(
                        'Sign in to your Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // "Don't have an account? Sign Up" text and button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupView(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF4D81E7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Combined email and password fields
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Email field
                            TextFormField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.mail,
                                  color: Color(0xFF375DFB),
                                ), // Changed to blue
                                hintText: 'eng491', // Changed this line
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.black),
                              onChanged: authViewModel.updateEmail,
                              textInputAction:
                                  TextInputAction.next, // Add this line
                            ),
                            const SizedBox(height: 10),
                            // Password field
                            TextFormField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFF375DFB),
                                ), // Changed to blue
                                hintText: '123456', // Changed this line
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              style: const TextStyle(color: Colors.black),
                              obscureText: _obscurePassword,
                              onChanged: authViewModel.updatePassword,
                              textInputAction:
                                  TextInputAction.done, // Add this line
                              onFieldSubmitted: (_) async {
                                // Add this block
                                if (authViewModel.email.isNotEmpty &&
                                    authViewModel.password.isNotEmpty) {
                                  // Trigger login
                                  FocusScope.of(context).unfocus();
                                  await authService.value.signIn(
                                    email: authViewModel.email,
                                    password: authViewModel.password,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // "Forgot Your Password?" button
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ResetPasswordView(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Your Password?',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Log In button
                      CustomButton(
                        text: 'Log In',
                        onPressed: () async {
                          if (authViewModel.email.isEmpty ||
                              authViewModel.password.isEmpty) {
                            _showError(
                              'Please enter valid email and password.',
                            );
                          } else {
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true; // Show loading
                            });

                            try {
                              await authService.value.signIn(
                                email: authViewModel.email,
                                password: authViewModel.password,
                              );

                              setState(() {
                                _isLoading = false; // Hide loading
                              });

                              _showSuccess('Login successful!');
                              await Future.delayed(
                                const Duration(seconds: 1),
                              ); // Reduced delay

                              if (mounted) {
                                await _handleSuccessfulLogin(context);
                              }
                            } on FirebaseAuthException catch (e) {
                              setState(() {
                                _isLoading = false; // Hide loading
                              });
                              _showError(
                                e.message ?? 'Login failed. Please try again.',
                              );
                            }
                          }
                        },
                        buttonType: 'main',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  // Popup error message
                  if (_showErrorPopup)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10.0),
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: _isSuccess ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _errorMessage ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  // Add this at the end of the Stack children list
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
