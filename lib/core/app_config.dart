import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A message shown to everyone in a dialog. It is shown once per [id] (the
/// admin screen makes a new id for each new message), or on every launch
/// when [repeat] is true.
class AppMessage {
  const AppMessage({
    required this.id,
    required this.title,
    required this.body,
    this.button = 'تمام',
    this.url = '',
    this.dismissible = true,
    this.repeat = false,
  });

  final String id, title, body, button, url;
  final bool dismissible, repeat;

  static AppMessage? fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final id = (raw['id'] ?? '').toString();
    final body = (raw['body'] ?? '').toString();
    if (id.isEmpty || body.isEmpty) {
      return null;
    }
    final button = (raw['button'] ?? '').toString();
    return AppMessage(
      id: id,
      title: (raw['title'] ?? '').toString(),
      body: body,
      button: button.isEmpty ? 'تمام' : button,
      url: (raw['url'] ?? '').toString(),
      dismissible: raw['dismissible'] != false,
      repeat: raw['repeat'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'button': button,
        'url': url,
        'dismissible': dismissible,
        'repeat': repeat,
      };
}

/// App-wide switches the admin controls from the app, stored in Firestore at
/// `config/app` and pushed live to every open app:
///
///   enabled          bool    false locks the app for everyone except admins
///   disabledMessage  string  text on the lock screen
///   message          map     see [AppMessage]; missing = no message
class AppConfig extends ChangeNotifier {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  static const defaultDisabledMessage = 'التطبيق متوقف حالياً، حاول لاحقاً.';

  static DocumentReference<Map<String, dynamic>> get doc =>
      FirebaseFirestore.instance.collection('config').doc('app');

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  bool _enabled = true;
  String _disabledMessage = defaultDisabledMessage;
  AppMessage? _message;

  bool get enabled => _enabled;
  String get disabledMessage => _disabledMessage;
  AppMessage? get message => _message;

  /// Starts listening; Firestore's offline cache keeps the last known state.
  void start() {
    _sub ??= doc.snapshots().listen((snap) {
      final m = snap.data() ?? const <String, dynamic>{};
      _enabled = m['enabled'] != false;
      final text = (m['disabledMessage'] ?? '').toString().trim();
      _disabledMessage = text.isEmpty ? defaultDisabledMessage : text;
      _message = AppMessage.fromMap(m['message']);
      notifyListeners();
    }, onError: (Object e) => debugPrint('config/app: $e'));
  }

  static Future<void> setEnabled(bool enabled, String disabledMessage) =>
      doc.set({'enabled': enabled, 'disabledMessage': disabledMessage.trim()}, SetOptions(merge: true));

  /// Publishes [m] as the current message, or removes it when null.
  static Future<void> setMessage(AppMessage? m) =>
      doc.set({'message': m?.toMap() ?? FieldValue.delete()}, SetOptions(merge: true));

  @visibleForTesting
  void debugSet({bool enabled = true, AppMessage? message}) {
    _enabled = enabled;
    _message = message;
    notifyListeners();
  }
}
