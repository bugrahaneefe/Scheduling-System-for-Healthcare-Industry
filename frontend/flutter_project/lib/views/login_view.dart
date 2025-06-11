// lib/views/login_view.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project491/components/custom_button.dart';
import 'package:project491/managers/auth_services.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:project491/views/reset_password_view.dart';
import 'package:project491/views/room_invitation_view.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'signup_view.dart';
import 'package:flutter/services.dart';
import 'home_view.dart';
import 'dart:async';
import 'package:email_validator/email_validator.dart';

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

  bool isValidEmail(String email) {
    return EmailValidator.validate(email);
  }

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
    if (!mounted) return;

    if (widget.pendingRoomId != null) {
      // Navigate to room invitation if there's a pending room
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => RoomInvitationView(
                roomId: widget.pendingRoomId!,
                returnToHome: true,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false, // Remove all previous routes
      );
    } else {
      // Navigate to home view as usual
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false, // Remove all previous routes
      );
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
      backgroundColor: const Color(0x1E1E1E),
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
                        color: Color(0xFF1D61E7),
                      ),
                      const SizedBox(height: 20),
                      // "Sign in to your Account" text
                      Text(
                        AppLocalizations.of(context).get('signInToAccount'),
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
                          Text(
                            AppLocalizations.of(context).get('dontHaveAccount'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder:
                                      (_, __, ___) => const SignupView(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                            child: Text(
                              AppLocalizations.of(context).get('signUp'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF1D61E7),
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
                              cursorColor: Color(0xFF1D61E7),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.mail,
                                  color: Color(0xFF1D61E7),
                                ), // Changed to blue
                                hintText: AppLocalizations.of(
                                  context,
                                ).get('email'),
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
                              cursorColor: Color(0xFF1D61E7),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFF1D61E7),
                                ), // Changed to blue
                                hintText: AppLocalizations.of(
                                  context,
                                ).get('password'),
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
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (_, __, ___) => const ResetPasswordView(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context).get('forgotPassword'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Log In button
                      CustomButton(
                        text: AppLocalizations.of(context).get('login2'),
                        onPressed: () async {
                          if (authViewModel.email.isEmpty ||
                              authViewModel.password.isEmpty) {
                            _showError(
                              AppLocalizations.of(
                                context,
                              ).get('enterValidEmailAndPassword'),
                            );
                          } else if (!isValidEmail(authViewModel.email)) {
                            _showError(
                              AppLocalizations.of(
                                context,
                              ).get('pleaseEnterValidEmail'),
                            );
                          } else {
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });

                            try {
                              await authService.value.signIn(
                                email: authViewModel.email,
                                password: authViewModel.password,
                              );

                              setState(() {
                                _isLoading = false; // Hide loading
                              });

                              _showSuccess(
                                AppLocalizations.of(
                                  context,
                                ).get('loginSuccessful'),
                              );
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
                                AppLocalizations.of(context).get('loginFailed'),
                              );
                            }
                          }
                        },
                        buttonType: 'main',
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });

                          try {
                            final result =
                                await authService.value.signInWithGoogle();

                            if (!mounted) return;
                            setState(() => _isLoading = false);

                            if (result == null) {
                              _showError(
                                AppLocalizations.of(
                                  context,
                                ).get('failGoogleSignIn'),
                              );
                              return;
                            }
                            _showSuccess(
                              AppLocalizations.of(
                                context,
                              ).get('loginSuccessful'),
                            );
                            await Future.delayed(const Duration(seconds: 1));

                            if (mounted) await _handleSuccessfulLogin(context);
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            _showError(
                              AppLocalizations.of(
                                context,
                              ).get('failGoogleSignIn'),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.all(
                            12,
                          ), // controls icon size and button space
                          elevation: 2,
                        ),
                        child: Image.asset(
                          'assets/images/google_icon.png',
                          height: 24,
                          width: 24,
                        ),
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
                      child: AbsorbPointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
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
