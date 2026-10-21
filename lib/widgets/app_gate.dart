import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/auth_service.dart';
import '../theme/app_theme.dart';
import 'fx.dart';

/// The app's navigator, so the gate can show dialogs above whatever route is open.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Sits above the navigator and applies [AppConfig]: covers the whole app for
/// signed-in regular users when the admin switches it off (admins and the
/// login screen stay open, so the admin can switch it back on), and shows the
/// admin's message dialog to signed-in regular users.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  static const _seenKey = 'app_seen_messages_v1';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AppConfig get _config => AppConfig.instance;

  Set<String>? _seen; // message ids already shown (persisted)
  final _shownThisRun = <String>{};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _config.addListener(_changed);
    AuthService.instance.addListener(_changed);
    _loadSeen();
  }

  @override
  void dispose() {
    _config.removeListener(_changed);
    AuthService.instance.removeListener(_changed);
    super.dispose();
  }

  Future<void> _loadSeen() async {
    try {
      // A stuck storage read must not hold the messages back forever.
      final raw = await _storage.read(key: _seenKey).timeout(const Duration(seconds: 2));
      _seen = raw == null ? <String>{} : (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      _seen = <String>{};
    }
    _changed();
  }

  Future<void> _markSeen(String id) async {
    _seen?.add(id);
    try {
      await _storage.write(key: _seenKey, value: jsonEncode(_seen!.toList())).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Only signed-in regular users are locked out. The login screen stays
  /// open, so the admin can always sign in and switch the app back on.
  bool get _blocked {
    final user = AuthService.instance.user;
    return !_config.enabled && user != null && !user.isAdmin;
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowMessage());
  }

  Future<void> _maybeShowMessage() async {
    final ctx = appNavigatorKey.currentContext;
    final msg = _config.message;
    // Messages are for regular users only: not the admin who wrote them, and
    // not the login screen (where we don't know who is who yet).
    final user = AuthService.instance.user;
    if (user == null || user.isAdmin) {
      return;
    }
    if (!mounted || _dialogOpen || _blocked || _seen == null || ctx == null || msg == null) {
      return;
    }
    if (_shownThisRun.contains(msg.id) || (!msg.repeat && _seen!.contains(msg.id))) {
      return;
    }
    _shownThisRun.add(msg.id);
    if (!msg.repeat) {
      await _markSeen(msg.id);
    }
    if (!ctx.mounted) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: msg.dismissible,
        builder: (dctx) => PopScope(
          canPop: msg.dismissible,
          child: AlertDialog(
            title: msg.title.isEmpty ? null : Text(msg.title),
            content: SingleChildScrollView(child: Text(msg.body)),
            actions: [
              if (msg.dismissible && msg.url.isNotEmpty)
                TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('إغلاق')),
              FilledButton(
                onPressed: () {
                  if (msg.url.isNotEmpty) {
                    _open(msg.url);
                  }
                  if (msg.dismissible) {
                    Navigator.pop(dctx);
                  }
                },
                child: Text(msg.button),
              ),
            ],
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
    // A newer message may have arrived while this one was open.
    _maybeShowMessage();
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return Stack(
      // Expand: with the app offstage the Stack would otherwise shrink to
      // nothing and the lock screen would be invisible.
      fit: StackFit.expand,
      children: [
        // Kept in the tree (just covered) so the navigation stack survives a lock.
        Offstage(offstage: blocked, child: widget.child),
        if (blocked) Positioned.fill(child: _LockView(message: _config.disabledMessage)),
      ],
    );
  }
}

class _LockView extends StatelessWidget {
  const _LockView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GlowPulse(
                  intensity: 1.4,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.purpleDeep,
                    child: Icon(Icons.block, size: 46, color: AppColors.purpleGlow),
                  ),
                ),
                const SizedBox(height: 24),
                const FlickerText('التطبيق متوقف', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
