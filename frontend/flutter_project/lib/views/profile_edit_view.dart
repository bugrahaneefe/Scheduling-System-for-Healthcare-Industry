import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:project491/views/login_view.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:project491/utils/app_localizations.dart';
import '../models/user_model.dart';
import '../managers/auth_services.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
              success
                  ? AppLocalizations.of(context).get('success')
                  : AppLocalizations.of(context).get('error'),
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
                child: Text(
                  AppLocalizations.of(context).get('ok'),
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Popup arka planı beyaz
        title: Text('Hesabı Sil'),
        content: Text('Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              // Border kaldırıldı
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide.none,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Hesabı Sil',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userId = user.uid;
      final firestore = FirebaseFirestore.instance;

      // 1. Kullanıcının rooms listesini çek
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userRooms = List<String>.from(userDoc.data()?['rooms'] ?? []);

      // 2. Her oda için host mu kontrol et
      for (final roomId in userRooms) {
        final roomDoc = await firestore.collection('rooms').doc(roomId).get();
        if (!roomDoc.exists) continue;
        final roomData = roomDoc.data()!;
        final participants = List<Map<String, dynamic>>.from(roomData['participants'] ?? []);

        // Host mu?
        final isHost = participants.any((p) => p['isHost'] == true && p['userId'] == userId);

        if (isHost) {
          // Host ise odayı tamamen sil
          await firestore.collection('rooms').doc(roomId).delete();
        } else {
          // Host değilse, assign olduğu participant'ı bul ve unassign et
          final idx = participants.indexWhere((p) => p['userId'] == userId);
          if (idx != -1) {
            participants[idx]['userId'] = '';
            participants[idx]['assignedUserName'] = null;
            await firestore.collection('rooms').doc(roomId).update({'participants': participants});
          }
        }
      }

      // 3. Firestore'dan kullanıcı verisini sil
      await firestore.collection('users').doc(userId).delete();

      // Firebase Authentication'dan kullanıcıyı sil
      await user.delete();

      // Kullanıcı silindikten sonra login ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginView()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silinirken hata oluştu: $e')),
      );
    }
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
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).get('name'),
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.person, color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).get('title'),
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.work, color: Colors.black),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.white,
                        textSelectionTheme: const TextSelectionThemeData(
                          cursorColor: Colors.black,
                          selectionHandleColor: Colors.black,
                        ),
                      ),
                      child: IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'TR',
                        style: const TextStyle(color: Colors.black),
                        dropdownTextStyle: const TextStyle(color: Colors.black),
                        cursorColor: Colors.black,
                        dropdownIcon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).get('phoneNumber'),
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: widget.user.phoneNumber,
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Colors.black,
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                        pickerDialogStyle: PickerDialogStyle(
                          backgroundColor: Colors.white,
                          countryCodeStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          countryNameStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          listTileDivider: const Divider(color: Colors.grey),
                          searchFieldInputDecoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).get('searchCountry'),
                            labelStyle: const TextStyle(color: Colors.black),
                            suffixIcon: const Icon(
                              Icons.search,
                              color: Colors.black,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                          searchFieldCursorColor: Colors.black,
                          listTilePadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          padding: const EdgeInsets.all(8),
                          width: MediaQuery.of(context).size.width * 0.9,
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
                          builder:
                              (context, child) => Theme(
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
                                  textSelectionTheme:
                                      const TextSelectionThemeData(
                                        cursorColor: Colors.black,
                                        selectionColor: Colors.black12,
                                      ),
                                  inputDecorationTheme:
                                      const InputDecorationTheme(
                                        labelStyle: TextStyle(
                                          color: Colors.black,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                          ),
                                        ),
                                        hintStyle: TextStyle(
                                          color: Colors.black,
                                        ), // Ensure "Enter date" text is black
                                      ),
                                ),
                                child: child!,
                              ),
                        );
                        if (picked != null)
                          setState(() => _selectedBirthday = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).get('birthday'),
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
                              : AppLocalizations.of(
                                context,
                              ).get('selectBirthday'),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center, // Ortada hizala
                children: [
                  ElevatedButton(
                    onPressed: _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Değişiklikleri Uygula ile aynı köşe
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Hesabı Sil',
                      style: TextStyle(color: Colors.white), // Yazı beyaz
                    ),
                  ),
                  const SizedBox(width: 12), // Aradaki boşluk azaltıldı
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  AppLocalizations.of(
                                    context,
                                  ).get('profileUpdated'),
                                  true,
                                );
                              } catch (e) {
                                await _showPopup(
                                  AppLocalizations.of(
                                    context,
                                  ).get('failedToUpdateProfile'),
                                  false,
                                );
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Text(
                              AppLocalizations.of(context).get('applyChanges'),
                              style: TextStyle(color: Colors.black),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
