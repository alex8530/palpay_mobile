# PalPay Console — Mobile (Flutter)

تطبيق موبايل مستقل، نسخة من لوحة PalPay في مشروع الويب (regForPal). التطبيق يوقّع
الطلبات ويكلّم PalPay مباشرة من الجهاز — **بلا أي سيرفر**. كل الإعدادات (بما فيها
الأسرار) تُخزّن مشفّرة على الجهاز عبر `flutter_secure_storage`.

> ملاحظة أمنية: هذا تطبيق شخصي. لا توزّعه — الأسرار مخزّنة داخله.

## المتطلبات

1. ثبّت **Flutter SDK** (يجيب معه Dart): <https://docs.flutter.dev/get-started/install/windows>
2. ثبّت **Android Studio** (للـ Android SDK والمحاكي)، أو وصّل جهاز Android عبر USB
   مع تفعيل *USB debugging*.
3. تأكّد إن كل شي تمام:
   ```
   flutter doctor
   ```

## التشغيل أول مرة

هذا المجلد فيه الكود المصدري فقط (`lib/`, `test/`, `pubspec.yaml`). ولّد مجلدات
المنصّات (android/…) ثم شغّل:

```bash
cd C:\Users\Alex\Desktop\palpay_mobile
flutter create . --platforms=android --org com.alex
flutter pub get
flutter run        # مع جهاز/محاكي متصل
```

`flutter create .` بيضيف مجلد `android/` وما بيمسح ملفاتنا في `lib/`.

### مهم: صلاحية الإنترنت لنسخة الـ release

وضع التطوير (`flutter run`) بيشتغل مباشرة. لكن لبناء APK للتوزيع الشخصي، أضف هذا
السطر داخل `<manifest>` في `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

ثم:
```bash
flutter build apk --release
# الناتج: build/app/outputs/flutter-apk/app-release.apk
```

## التحقق من التوقيع (مهم)

منطق التوقيع منقول حرفياً من كود PHP. فيه اختبار يثبت التطابق byte-for-byte:

```bash
flutter test
```

لازم تنجح كل اختبارات `test/palpay_signer_test.dart`. لو فشلت، معناها التوقيع
مختلف عن الويب وPalPay رح يرفض الطلبات.

## الاستخدام

1. افتح **الإعدادات** (أيقونة الترس) واملأ `USERNAME` و`PASSWORD` و`SALT`
   و`ACCESS_TOKEN` حسب حالتك. (نفس قيم الويب.)
2. ارجع للرئيسية، اختر ركوست، عبّي الحقول، واضغط **إرسال**.
3. القيم المهمة من الرد (token, FROM_ACCOUNT…) تُحفظ تلقائياً.
4. **وضع المطور** في الإعدادات يُظهر/يُخفي الرابط والـ response الخام وسجل الطلب.

## البنية

```
lib/
  core/
    palpay_signer.dart     التوقيع (SHA256/MD5/HMAC/Base64)
    palpay_requests.dart   سجل كل الركوستات
    palpay_client.dart     بناء الهيدرز + الإرسال + قواعد الحفظ
    settings_store.dart    تخزين آمن على الجهاز
    result_utils.dart      استخراج جدول الحركات من الرد
  models/request_def.dart
  screens/   home / settings / request
  widgets/   account_cards / transactions_table
test/palpay_signer_test.dart   تطابق التوقيع مع PHP
```
