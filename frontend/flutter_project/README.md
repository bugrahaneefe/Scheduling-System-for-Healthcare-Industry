# project491

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Apple ile Giriş Kurulumu

## 1. sign_in_with_apple paketini ekleyin

`pubspec.yaml` dosyanıza ekleyin:
```yaml
dependencies:
  sign_in_with_apple: ^5.0.0
```
Sonra terminalde:
```
flutter pub get
```

## 2. Apple logosunu ekleyin

- `assets/images/apple_icon.png` dosyasını projenizdeki ilgili klasöre ekleyin.
- `pubspec.yaml` dosyanızda assets kısmında tanımlı olduğundan emin olun:
```yaml
flutter:
  assets:
    - assets/images/apple_icon.png
```

## 3. iOS için gerekli ayarlar

### a) Apple Developer hesabınızda "Sign in with Apple" özelliğini açın

- [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) paneline gidin.
- Uygulamanızın Bundle ID'sini seçin.
- "Sign In with Apple" özelliğini etkinleştirin.

### b) Xcode'da Capability ekleyin

- Xcode'da Runner projenizi açın.
- Target > Signing & Capabilities sekmesine gelin.
- "+ Capability" butonuna tıklayın ve "Sign In with Apple" ekleyin.

### c) Info.plist ayarları

`ios/Runner/Info.plist` dosyasına aşağıdaki satırı ekleyin:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
  </dict>
</array>
```

### d) Minimum iOS Sürümü

`ios/Podfile` dosyanızda minimum platformu en az 13.0 yapın:
```
platform :ios, '13.0'
```

## 4. Test

- Gerçek bir cihazda test edin (Apple ile giriş simülatörde çalışmaz).
- Apple hesabınızda test kullanıcıları oluşturabilirsiniz.

Daha fazla bilgi için:
- [sign_in_with_apple Flutter package](https://pub.dev/packages/sign_in_with_apple)
- [Apple resmi dokümantasyonu](https://developer.apple.com/documentation/sign_in_with_apple)
