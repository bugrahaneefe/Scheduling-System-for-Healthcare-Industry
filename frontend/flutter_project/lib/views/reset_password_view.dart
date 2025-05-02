import 'package:flutter/material.dart';
import '../managers/auth_services.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({Key? key}) : super(key: key);

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await authService.value.resetPassword(_emailController.text.trim());
      setState(() {
        _message = 'Password reset email sent! Check your inbox.';
        _isSuccess = true;
      });
      Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
    } catch (e) {
      setState(() {
        _message = 'Failed to send reset email. Please try again.';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Makes back button white
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              style: const TextStyle(
                color: Colors.white,
              ), // Makes input text white
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.white,
                ), // Makes label text white
                hintText: 'Enter your email address',
                hintStyle: TextStyle(
                  color: Colors.white70,
                ), // Makes hint text white with opacity
                prefixIcon: Icon(
                  Icons.email,
                  color: Colors.white,
                ), // Makes icon white
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white, // White background
              ),
              onPressed: _isLoading ? null : _resetPassword,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Send Reset Link'),
            ),
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
