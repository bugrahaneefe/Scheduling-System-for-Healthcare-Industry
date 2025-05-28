import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
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
  late String _completePhoneNumber;
  DateTime? _selectedBirthday;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _titleController = TextEditingController(text: widget.user.title);
    final rawNumber = widget.user.phoneNumber.replaceFirst(
      RegExp(r'^\+\d+'),
      '',
    );
    _phoneController = TextEditingController(text: rawNumber);
    _completePhoneNumber = widget.user.phoneNumber;
    _selectedBirthday = widget.user.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showPopup(String message, bool success) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              success ? 'Success' : 'Error',
              style: const TextStyle(color: Colors.black),
            ),
            content: Text(message, style: const TextStyle(color: Colors.black)),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  if (success) Navigator.of(context).pop(); // close sheet
                },
                child: const Text('OK', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.black),
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
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.person, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.work, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(canvasColor: Colors.white),
                      child: IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'TR',
                        style: const TextStyle(color: Colors.black),
                        dropdownTextStyle: const TextStyle(color: Colors.black),
                        dropdownIcon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: widget.user.phoneNumber,
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Colors.black,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        pickerDialogStyle: PickerDialogStyle(
                          backgroundColor: Colors.white, // sheet background
                          countryCodeStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          countryNameStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          listTileDivider: const Divider(color: Colors.grey),
                          listTilePadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          padding: const EdgeInsets.all(8),
                          searchFieldCursorColor: Colors.black,
                          searchFieldPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          width:
                              MediaQuery.of(context).size.width *
                              0.9, // optional
                        ),
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedBirthday ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF1D61E7),
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              dialogBackgroundColor: Colors.white,
                              textSelectionTheme: const TextSelectionThemeData(
                                cursorColor: Colors.black,
                                selectionColor: Colors.black12,
                              ),
                              inputDecorationTheme: const InputDecorationTheme(
                                labelStyle: TextStyle(color: Colors.black),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                                hintStyle: TextStyle(color: Colors.black), // Ensure "Enter date" text is black
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null)
                          setState(() => _selectedBirthday = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Birthday',
                          labelStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(
                            Icons.calendar_today,
                            color: Colors.black,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedBirthday != null
                              ? "${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}"
                              : 'Select Birthday',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () async {
                          setState(() => _isLoading = true);
                          try {
                            // 1) Save
                            await authService.value.updateUserProfile(
                              name: _nameController.text,
                              title: _titleController.text,
                              phoneNumber: _completePhoneNumber,
                              birthday: _selectedBirthday!,
                            );
                            // 2) Reload user data – same as your pull-to-refresh
                            await Provider.of<AuthViewModel>(
                              context,
                              listen: false,
                            ).loadCurrentUser();
                            // 3) Show popup & close
                            await _showPopup(
                              'Profile updated successfully!',
                              true,
                            );
                          } catch (e) {
                            await _showPopup('Failed to update profile', false);
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                        : const Text(
                          'Apply Changes',
                          style: TextStyle(color: Colors.black),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
