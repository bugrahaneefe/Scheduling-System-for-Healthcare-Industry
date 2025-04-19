import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../managers/auth_services.dart';
import '../viewmodels/auth_viewmodel.dart';

class ProfileEditView extends StatefulWidget {
  final UserModel user;

  const ProfileEditView({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _phoneController;
  DateTime? _selectedBirthday;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showErrorPopup = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _titleController = TextEditingController(text: widget.user.title);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _selectedBirthday = widget.user.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message, bool isSuccess) {
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
      _isSuccess = isSuccess;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showErrorPopup = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.work),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedBirthday ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedBirthday = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthday',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedBirthday != null
                          ? "${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}"
                          : 'Select Birthday',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                _isLoading
                    ? null
                    : () async {
                      setState(() => _isLoading = true);
                      try {
                        await authService.value.updateUserProfile(
                          name: _nameController.text,
                          title: _titleController.text,
                          phoneNumber: _phoneController.text,
                          birthday: _selectedBirthday!,
                        );

                        if (mounted) {
                          Provider.of<AuthViewModel>(
                            context,
                            listen: false,
                          ).loadCurrentUser();
                          _showMessage('Profile updated successfully!', true);
                          Future.delayed(
                            const Duration(seconds: 1),
                            () => Navigator.pop(context),
                          );
                        }
                      } catch (e) {
                        _showMessage('Failed to update profile', false);
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
            child:
                _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Apply Changes'),
          ),
          if (_showErrorPopup)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isSuccess ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
