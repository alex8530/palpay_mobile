import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// One app account. Its profile lives in Firestore at `users/{phone}` and its
/// login is a Firebase Auth email/password account `{phone}@palpay-mobile.app`.
/// The password is also kept in the profile so the admin can see it; the
/// Firestore rules let only the admin read other users' profiles.
class AppUser {
  const AppUser({
    required this.phone,
    required this.name,
    required this.password,
    this.role = 'user',
    this.active = true,
    this.createdAt,
  });

  final String phone, name, password, role;
  final bool active;
  final DateTime? createdAt;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(String phone, Map<String, dynamic> m) => AppUser(
        phone: phone,
        name: (m['name'] ?? '').toString(),
        password: (m['password'] ?? '').toString(),
        role: m['role'] == 'admin' ? 'admin' : 'user',
        active: m['active'] != false,
        createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
      );

  /// Fields written to Firestore (createdAt is set by the server on create).
  Map<String, dynamic> toMap() => {
        'phone': phone,
        'name': name,
        'password': password,
        'role': role,
        'active': active,
      };
}

/// Phone + password login through Firebase Auth. The user's profile is
/// watched so that disabling, deleting or changing the password of a user
/// signs them out right away.
class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Firebase Auth needs an email; the phone becomes `{phone}@palpay-mobile.app`.
  static const emailDomain = 'palpay-mobile.app';

  /// Firebase Auth rejects passwords shorter than this.
  static const minPasswordLength = 6;

  static String emailFor(String phone) => '$phone@$emailDomain';

  static CollectionReference<Map<String, dynamic>> get users =>
      FirebaseFirestore.instance.collection('users');

  AppUser? _user;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  AppUser? get user => _user;

  /// Digits only, so "059 912-3456" and "0599123456" are the same account.
  static String normalizePhone(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Restores the Firebase Auth session kept on the device, if any.
  Future<void> restore() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    final email = fbUser?.email ?? '';
    if (!email.endsWith('@$emailDomain')) {
      return;
    }
    final phone = email.split('@').first;
    try {
      // Online this checks the server; offline it falls back to the cache.
      final doc = await users.doc(phone).get().timeout(const Duration(seconds: 8));
      final found = doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;
      if (found == null || !found.active) {
        await logout();
        return;
      }
      _start(found);
    } catch (_) {
      // No server and nothing cached: stay logged out until next launch.
    }
  }

  /// Returns an Arabic error message, or null on success.
  Future<String?> login(String phone, String password) async {
    phone = normalizePhone(phone);
    if (phone.isEmpty || password.isEmpty) {
      return 'اكتب رقم الجوال وكلمة السر.';
    }
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailFor(phone), password: password)
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return 'تعذّر الاتصال، تأكد من الإنترنت وحاول مرة ثانية.';
      }
      if (e.code == 'user-disabled') {
        return 'هذا الحساب موقوف، تواصل مع الإدارة.';
      }
      if (e.code == 'too-many-requests') {
        return 'محاولات كثيرة، استنى شوي وجرب مرة ثانية.';
      }
      return 'رقم الجوال أو كلمة السر غير صحيحة.';
    } catch (_) {
      return 'تعذّر الاتصال، تأكد من الإنترنت وحاول مرة ثانية.';
    }

    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await users.doc(phone).get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 15));
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return 'تعذّر الاتصال، تأكد من الإنترنت وحاول مرة ثانية.';
    }
    final found = doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;
    if (found == null || !found.active) {
      await FirebaseAuth.instance.signOut();
      return found == null ? 'هذا الحساب غير موجود.' : 'هذا الحساب موقوف، تواصل مع الإدارة.';
    }
    _start(found);
    return null;
  }

  Future<void> logout() async {
    await _sub?.cancel();
    _sub = null;
    _user = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    notifyListeners();
  }

  /// Call before saving your own account, so the change doesn't read as
  /// "password changed elsewhere" and sign you out.
  void adoptOwnChanges(AppUser u) {
    if (u.phone != _user?.phone) {
      return;
    }
    _user = u;
    notifyListeners();
  }

  void _start(AppUser u) {
    _user = u;
    notifyListeners();
    _sub?.cancel();
    _sub = users.doc(u.phone).snapshots().listen((doc) {
      final current = _user;
      // Only a server answer can sign someone out, never a cache miss.
      if (current == null || doc.metadata.isFromCache) {
        return;
      }
      final fresh = doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;
      if (fresh == null || !fresh.active || fresh.password != current.password) {
        logout();
        return;
      }
      _user = fresh;
      notifyListeners();
    }, onError: (Object e) {
      // Permission denied = the profile was deleted or disabled under us.
      if (e is FirebaseException && e.code == 'permission-denied') {
        logout();
      }
    });
  }

  @visibleForTesting
  void debugSetUser(AppUser? u) {
    _user = u;
    notifyListeners();
  }
}

/// Admin-only account operations. They run on a second Firebase app so that
/// signing in as another user never touches the admin's own session.
class UserAdmin {
  static Future<FirebaseAuth> _auth() async {
    const name = 'user-admin';
    final app = Firebase.apps.where((a) => a.name == name).firstOrNull ??
        await Firebase.initializeApp(name: name, options: Firebase.app().options);
    return FirebaseAuth.instanceFor(app: app);
  }

  /// Creates the login and the profile. Throws an Arabic message on failure.
  static Future<void> create(AppUser u) async {
    final ref = AuthService.users.doc(u.phone);
    if ((await ref.get(const GetOptions(source: Source.server))).exists) {
      throw 'هذا الرقم مسجل مسبقاً.';
    }
    final auth = await _auth();
    String uid;
    try {
      try {
        await auth.createUserWithEmailAndPassword(email: AuthService.emailFor(u.phone), password: u.password);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') throw _message(e);
        // A login left over from a deleted profile: reuse it if the password matches.
        await _signIn(auth, u.phone, u.password);
      }
      uid = auth.currentUser!.uid;
    } finally {
      await auth.signOut();
    }
    // The rules only accept a login whose uid matches the profile's.
    await ref.set({...u.toMap(), 'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
  }

  /// Saves profile changes; when the password changed, changes the login too.
  static Future<void> update(AppUser before, AppUser after) async {
    if (before.password != after.password) {
      await _changePassword(before.phone, before.password, after.password);
    }
    await AuthService.users.doc(after.phone).update(after.toMap());
  }

  /// Deletes the login and the profile (their past requests stay). Without a
  /// profile the login is useless anyway, so a login that can't be removed
  /// (already gone, password out of sync) doesn't block the delete.
  static Future<void> delete(AppUser u) async {
    final auth = await _auth();
    try {
      await auth.signInWithEmailAndPassword(email: AuthService.emailFor(u.phone), password: u.password);
      await auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') throw _message(e);
    } finally {
      await auth.signOut();
    }
    await AuthService.users.doc(u.phone).delete();
  }

  static Future<void> _changePassword(String phone, String oldPassword, String newPassword) async {
    final me = FirebaseAuth.instance.currentUser;
    try {
      if (me != null && me.email == AuthService.emailFor(phone)) {
        // Your own account: change it on the main session so you stay signed in.
        await me.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: me.email!, password: oldPassword),
        );
        await me.updatePassword(newPassword);
        return;
      }
      final auth = await _auth();
      try {
        await _signIn(auth, phone, oldPassword);
        await auth.currentUser!.updatePassword(newPassword);
      } finally {
        await auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      throw _message(e);
    }
  }

  static Future<void> _signIn(FirebaseAuth auth, String phone, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: AuthService.emailFor(phone), password: password);
    } on FirebaseAuthException catch (e) {
      throw e.code == 'network-request-failed'
          ? _message(e)
          : 'كلمة السر المحفوظة لهذا المستخدم لا تطابق حسابه. احذفه وأضفه من جديد.';
    }
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'weak-password' => 'كلمة السر لازم تكون ${AuthService.minPasswordLength} أحرف على الأقل.',
        'network-request-failed' => 'تعذّر الاتصال، تأكد من الإنترنت.',
        'operation-not-allowed' => 'تسجيل الدخول بالإيميل وكلمة السر غير مفعّل في Firebase.',
        _ => 'خطأ من Firebase: ${e.code}',
      };
}
