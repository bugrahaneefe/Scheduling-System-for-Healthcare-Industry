import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:project491/managers/auth_services.dart';
import 'package:project491/utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'package:project491/components/custom_button.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SignupView extends StatefulWidget {
  const SignupView({Key? key}) : super(key: key);

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // For displaying an error popup (like in LoginView)
  String? _errorMessage;
  bool _showErrorPopup = false;

  // Add a variable to store the selected birthday
  String? _selectedBirthday;

  // Add this boolean to track if it's a success message
  bool _isSuccess = false;

  bool _isLoading = false;

  // Add this variable to track the "Hide my email" checkbox
  bool _hideEmail = false;

  bool isValidPassword(String password) {
    return password.length >= 6;
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _showErrorPopup = false;
      });
    });
  }

  void _showSuccess(String message) {
    setState(() {
      _errorMessage = message;
      _showErrorPopup = true;
      _isSuccess = true; // Set success state to true
    });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _showErrorPopup = false;
        _isSuccess = false; // Reset success state
      });
    });
  }

  // Hash fonksiyonu
  String _hashEmail(String email) {
    return sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0x1E1E1E),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).get('signUp'),
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0x1E1E1E),
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16.0,
              16.0,
              16.0,
              MediaQuery.of(context).viewInsets.bottom + 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Stack(
                children: [
                  // Main column of content
                  Column(
                    children: [
                      // Calendar icon
                      const Icon(
                        Icons.calendar_today,
                        size: 48,
                        color: Color(0xFF1D61E7),
                      ),
                      const SizedBox(height: 20),
                      // "Create Account" text
                      Text(
                        AppLocalizations.of(context).get('createAccount'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // "Already have an account? Log in" row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(
                              context,
                            ).get('alreadyHaveAccount'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate back to the previous page
                              Navigator.pop(context);
                            },
                            child: Text(
                              AppLocalizations.of(context).get('login2'),
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
                      // White container for name, email, birthday, phone number, and password
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
                            // Name field
                            TextFormField(
                              keyboardType: TextInputType.text,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z\s]'),
                                ), // Allow only alphabetic letters and spaces
                              ],
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: Color(0xFF1D61E7),
                                ),
                                hintText: AppLocalizations.of(
                                  context,
                                ).get('nameSurname'),
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.black),
                              cursorColor: Color(
                                0xFF1D61E7,
                              ), // Updated cursor color
                              onChanged:
                                  authViewModel
                                      .updateName, // Add this method in AuthViewModel
                            ),
                            const SizedBox(height: 10),
                            // Title field
                            TextFormField(
                              keyboardType: TextInputType.text,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z\s]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.work,
                                  color: Color(0xFF1D61E7),
                                ),
                                hintText: AppLocalizations.of(context).get('jobDescription') +
                                    " (${Localizations.localeOf(context).languageCode == 'tr' ? 'İsteğe Bağlı' : 'Optional'})",
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.black),
                              cursorColor: Color(0xFF1D61E7),
                              onChanged: authViewModel.updateTitle,
                            ),
                            const SizedBox(height: 10),
                            // Birthday field
                            TextFormField(
                              readOnly: true,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF1D61E7),
                                ),
                                hintText: _selectedBirthday == null
                                    ? AppLocalizations.of(context).get('selectBirthday') +
                                        " (${Localizations.localeOf(context).languageCode == 'tr' ? 'İsteğe Bağlı' : 'Optional'})"
                                    : _selectedBirthday!,
                                hintStyle: TextStyle(
                                  color: _selectedBirthday == null ? Colors.grey : Colors.black,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                              ),
                              style: TextStyle(
                                color: _selectedBirthday == null ? Colors.grey : Colors.black,
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(
                                    DateTime.now().year - 20,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                  ),
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
                                                selectionHandleColor:
                                                    Colors.black,
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
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                        width: 2,
                                                      ),
                                                    ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                hintStyle: TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                        ),
                                        child: child!,
                                      ),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    _selectedBirthday =
                                        "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                                  });
                                  authViewModel.updateBirthday(pickedDate);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            // Phone number field
                            Theme(
                              data: Theme.of(context).copyWith(canvasColor: Colors.white),
                              child: IntlPhoneField(
                                initialCountryCode: 'TR',
                                style: const TextStyle(color: Colors.black),
                                dropdownTextStyle: const TextStyle(
                                  color: Colors.black,
                                ),
                                cursorColor: const Color(0xFF1D61E7),
                                dropdownIcon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF1D61E7),
                                ),
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context).get('phoneNumber') +
                                      " (${Localizations.localeOf(context).languageCode == 'tr' ? 'İsteğe Bağlı' : 'Optional'})",
                                  labelStyle: const TextStyle(
                                    color: Colors.black,
                                  ),
                                  border: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF1D61E7),
                                    ),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF1D61E7),
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Color(0xFF1D61E7),
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
                                  listTileDivider: const Divider(
                                    color: Colors.grey,
                                  ),
                                  listTilePadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  searchFieldCursorColor: Color(0xFF1D61E7),
                                  searchFieldPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  width: MediaQuery.of(context).size.width * .9,
                                ),
                                onChanged: (phone) => authViewModel.updatePhoneNumber(
                                  phone.completeNumber,
                                ),
                              ),
                            ),
                            const Divider(color: Colors.black),
                            // Email field
                            TextFormField(
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.mail,
                                  color: Color(0xFF1D61E7),
                                ),
                                hintText: AppLocalizations.of(
                                  context,
                                ).get('email'),
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10.0,
                                  horizontal: 10.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.black),
                              cursorColor: Color(
                                0xFF1D61E7,
                              ), // Updated cursor color
                              onChanged: authViewModel.updateEmail,
                            ),
                            const SizedBox(height: 10),
                            // Password field
                            TextFormField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xFF1D61E7),
                                ),
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
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) async {
                                if (_formKey.currentState!.validate() &&
                                    authViewModel.email.isNotEmpty &&
                                    authViewModel.password.isNotEmpty &&
                                    authViewModel.name.isNotEmpty &&
                                    authViewModel.title.isNotEmpty &&
                                    authViewModel.phoneNumber.isNotEmpty &&
                                    authViewModel.birthday != null) {
                                  if (!isValidPassword(
                                    authViewModel.password,
                                  )) {
                                    _showError(
                                      AppLocalizations.of(
                                        context,
                                      ).get('passwordAtLeast6Chars'),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _errorMessage = null;
                                    _isLoading = true;
                                  });

                                  try {
                                    await authService.value.signUp(
                                      email: authViewModel.email,
                                      password: authViewModel.password,
                                      name: authViewModel.name,
                                      title: authViewModel.title,
                                      birthday: authViewModel.birthday!,
                                      phoneNumber: authViewModel.phoneNumber,
                                    );

                                    setState(() {
                                      _isLoading = false;
                                    });

                                    _showSuccess(
                                      AppLocalizations.of(
                                        context,
                                      ).get('registrationSuccessful'),
                                    );
                                    authViewModel.clearUserData();

                                    await Future.delayed(
                                      const Duration(seconds: 1),
                                    );

                                    if (mounted) {
                                      Navigator.pop(context);
                                    }
                                  } on FirebaseAuthException catch (e) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    _showError(
                                      e.message ??
                                          AppLocalizations.of(
                                            context,
                                          ).get('errorOccurred'),
                                    );
                                  }
                                } else {
                                  _showError(
                                    AppLocalizations.of(
                                      context,
                                    ).get('fillRequiredFields'),
                                  );
                                }
                              },
                              style: const TextStyle(color: Colors.black),
                              obscureText: _obscurePassword,
                              cursorColor: Color(
                                0xFF1D61E7,
                              ), // Updated cursor color
                              onChanged: authViewModel.updatePassword,
                            ),
                            const SizedBox(height: 10),
                            // Emailimi gizle checkboxı
                            Row(
                              children: [
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    unselectedWidgetColor: Colors.white, // kutu kenarı ve içi başta beyaz
                                    checkboxTheme: CheckboxThemeData(
                                      fillColor: MaterialStateProperty.resolveWith<Color>(
                                        (states) =>
                                            states.contains(MaterialState.selected)
                                                ? Color(0xFF1D61E7) // tıklanınca mavi
                                                : Colors.white, // başta beyaz
                                      ),
                                      checkColor: MaterialStateProperty.all<Color>(Colors.white),
                                    ),
                                  ),
                                  child: Checkbox(
                                    value: _hideEmail,
                                    onChanged: (val) {
                                      setState(() {
                                        _hideEmail = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'tr'
                                      ? "Emailimi gizle"
                                      : "Hide my email",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Sign Up button
                      CustomButton(
                        text: AppLocalizations.of(context).get('register'),
                        onPressed: () async {
                          if (_formKey.currentState!.validate() &&
                              authViewModel.email.isNotEmpty &&
                              authViewModel.password.isNotEmpty &&
                              authViewModel.name.isNotEmpty
                              // title, phoneNumber, birthday artık zorunlu değil!
                          ) {
                            if (!isValidPassword(authViewModel.password)) {
                              _showError(
                                AppLocalizations.of(
                                  context,
                                ).get('passwordAtLeast6Chars'),
                              );
                              return;
                            }
                            setState(() {
                              _errorMessage = null;
                              _isLoading = true;
                            });

                            try {
                              // E-mail formatı kontrolü ekle
                              final email = authViewModel.email.trim();
                              final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
                              if (!_hideEmail && !emailRegex.hasMatch(email)) {
                                setState(() {
                                  _isLoading = false;
                                });
                                _showError(AppLocalizations.of(context).get('pleaseEnterValidEmail'));
                                return;
                              }

                              // Hem normal email hem hashli email ile kayıtlı kullanıcı var mı kontrol et
                              final hash = _hashEmail(authViewModel.email);
                              final hashedEmail = "$hash@example.com";
                              final normalEmail = authViewModel.email;

                              final normalEmailQuery = await FirebaseAuth.instance.fetchSignInMethodsForEmail(normalEmail).catchError((_) => []);
                              final hashedEmailQuery = await FirebaseAuth.instance.fetchSignInMethodsForEmail(hashedEmail).catchError((_) => []);

                              if (normalEmailQuery.isNotEmpty || hashedEmailQuery.isNotEmpty) {
                                setState(() {
                                  _isLoading = false;
                                });
                                _showError(AppLocalizations.of(context).get('emailAlreadyInUse') ?? "Bu email zaten kullanılıyor.");
                                return;
                              }

                              // Eğer email gizli ise hashle ve @example.com ekle
                              String emailToSave;
                              if (_hideEmail) {
                                emailToSave = hashedEmail;
                              } else {
                                emailToSave = normalEmail;
                              }

                              await authService.value.signUp(
                                email: emailToSave,
                                password: authViewModel.password,
                                name: authViewModel.name,
                                title: authViewModel.title.isNotEmpty ? authViewModel.title : "",
                                birthday: authViewModel.birthday ?? DateTime(2000, 1, 1),
                                phoneNumber: authViewModel.phoneNumber.isNotEmpty ? authViewModel.phoneNumber : "",
                              );

                              setState(() {
                                _isLoading = false;
                              });

                              _showSuccess(
                                AppLocalizations.of(
                                  context,
                                ).get('registrationSuccessful'),
                              );
                              authViewModel.clearUserData();

                              await Future.delayed(const Duration(seconds: 1));

                              if (mounted) {
                                Navigator.pop(context);
                              }
                            } on FirebaseAuthException catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              _showError(
                                e.message ??
                                    AppLocalizations.of(
                                      context,
                                    ).get('errorOccurred'),
                              );
                            }
                          } else {
                            _showError(
                              AppLocalizations.of(
                                context,
                              ).get('fillRequiredFields'),
                            );
                          }
                        },
                        buttonType: 'main',
                      ),
                    ],
                  ),
                  // Popup error message (appears at the top of the Stack)
                  if (_showErrorPopup)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(10.0),
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color:
                              _isSuccess
                                  ? Colors.green
                                  : Colors.red, // Change color based on state
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
                  // Add loading indicator overlay
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
