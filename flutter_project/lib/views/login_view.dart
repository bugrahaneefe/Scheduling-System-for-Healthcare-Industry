// lib/views/login_view.dart

import 'package:flutter/material.dart';
import 'package:project491/components/custom_button.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'signup_view.dart';
import 'package:flutter/services.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _showErrorPopup = false;

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _showErrorPopup = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: null, // Removed the title
      ),
      body: Padding(
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
                            MaterialPageRoute(builder: (_) => const SignupView()),
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
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
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
                            prefixIcon: const Icon(Icons.mail, color: Color(0xFF375DFB)), // Changed to blue
                            hintText: 'email or phone number',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                          ),
                          style: const TextStyle(color: Colors.black),
                          onChanged: authViewModel.updateEmail,
                        ),
                        const SizedBox(height: 10),
                        // Password field
                        TextFormField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock, color: Color(0xFF375DFB)), // Changed to blue
                            hintText: '********',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // "Forgot Your Password?" button
                  TextButton(
                    onPressed: () {
                      // TODO: Implement "Forgot Password?" feature
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
                    onPressed: () {
                      if (authViewModel.email.isEmpty || authViewModel.password.isEmpty) {
                        _showError('Please enter valid email and password.');
                      } else {
                        setState(() {
                          _errorMessage = null;
                        });
                        // TODO: Call authViewModel.signIn() once Firebase is implemented
                      }
                    }, buttonType: 'main',
                  ),
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
                      color: Colors.red,
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
            ],
          ),
        ),
      ),
    );
  }
}
