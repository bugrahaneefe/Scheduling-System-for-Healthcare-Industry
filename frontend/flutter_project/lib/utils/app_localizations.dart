import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'createAccount': 'Create Account',
      'alreadyHaveAccount': 'Already have an account?',
      'login': 'Log in',
      'nameSurname': 'Name & Surname',
      'jobDescription': 'Job Description',
      'selectBirthday': 'Select Birthday',
      'phoneNumber': 'Phone Number',
      'password': 'Password',
      'register': 'Register',
      'registrationSuccessful': 'Registration successful!',
      'fillRequiredFields': 'Please fill in all required fields.',
      'errorOccurred': 'An error occurred. Please try again.',
      'editProfile': 'Edit Profile',
      'logout': 'Logout',
      'myRooms': 'My Rooms',
      'noRoomAssigned': 'No room assigned',
      'noNotifications': 'No notifications',
      'createNewRoom': 'Create New Room',
      'roomName': 'Room Name',
      'description': 'Description',
      'firstDay': 'First Day',
      'lastDay': 'Last Day',
      'defaultShiftsCount': 'Default Number of Shifts',
      'enterDefaultShifts': 'Enter default number of shifts for each participant',
      'editDailyShifts': 'Edit Daily Required Shifts',
      'setAllDaysTo': 'Set all days to:',
      'apply': 'Apply',
      'done': 'Done',
      'addParticipant': 'Add Participant',
      'participants': 'Participants:',
      'host': 'Host',
      'createRoom': 'Create Room',
      'confirmDelete': 'Confirm Delete',
      'sureToConfirmDeleteRoom': 'Are you sure you want to delete this room?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'unnamedRoom': 'Unnamed Room',
      'noDescription': 'No description',
      'invalidShifts': 'Invalid Shifts',
      'ok': 'OK',
      // ... add all other English strings
    },
    'tr': {
      'createAccount': 'Hesap Oluştur',
      'alreadyHaveAccount': 'Hesabınız var mı?',
      'login': 'Giriş Yap',
      'nameSurname': 'Ad & Soyad',
      'jobDescription': 'İş Tanımı',
      'selectBirthday': 'Doğum Tarihi Seç',
      'phoneNumber': 'Telefon Numarası',
      'password': 'Şifre',
      'register': 'Kayıt Ol',
      'registrationSuccessful': 'Kayıt başarılı!',
      'fillRequiredFields': 'Lütfen tüm zorunlu alanları doldurun.',
      'errorOccurred': 'Bir hata oluştu. Lütfen tekrar deneyin.',
      'editProfile': 'Profili Düzenle',
      'logout': 'Çıkış Yap',
      'myRooms': 'Odalarım',
      'noRoomAssigned': 'Atanmış oda yok',
      'noNotifications': 'Bildirim yok',
      'createNewRoom': 'Yeni Oda Oluştur',
      'roomName': 'Oda Adı',
      'description': 'Açıklama',
      'firstDay': 'Başlangıç Tarihi',
      'lastDay': 'Bitiş Tarihi',
      'defaultShiftsCount': 'Varsayılan Kişi Başı Nöbet Sayısı',
      'enterDefaultShifts': 'Her katılımcı için varsayılan nöbet sayısını girin',
      'editDailyShifts': 'Günlük Gerekli Nöbet Sayılarını Düzenle',
      'setAllDaysTo': 'Tüm günleri ayarla:',
      'apply': 'Uygula',
      'done': 'Tamamlandı',
      'addParticipant': 'Katılımcı Ekle',
      'participants': 'Katılımcılar:',
      'host': 'Yönetici',
      'createRoom': 'Oda Oluştur',
      'confirmDelete': 'Silmeyi Onaylayın',
      'sureToConfirmDeleteRoom': 'Bu odayı silmek istediğinizden emin misiniz?',
      'cancel': 'İptal',
      'delete': 'Sil',
      'unnamedRoom': 'İsimsiz Oda',
      'noDescription': 'Açıklama yok',
      'invalidShifts': 'Geçersiz Nöbet Sayıları',
      'ok': 'Tamam',
      // ... add all other Turkish strings
    }
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'tr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
