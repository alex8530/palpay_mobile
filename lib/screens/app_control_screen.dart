import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';

/// Admin: switch the app on/off for users and publish a message dialog.
/// Saved to `config/app`; every open app picks it up within seconds.
class AppControlScreen extends StatefulWidget {
  const AppControlScreen({super.key});

  @override
  State<AppControlScreen> createState() => _AppControlScreenState();
}

class _AppControlScreenState extends State<AppControlScreen> {
  final _config = AppConfig.instance;
  late final _disabledMessage = TextEditingController(text: _config.disabledMessage);
  late final _title = TextEditingController(text: _config.message?.title);
  late final _body = TextEditingController(text: _config.message?.body);
  late final _button = TextEditingController(text: _config.message?.button ?? 'تمام');
  late final _url = TextEditingController(text: _config.message?.url);
  late bool _dismissible = _config.message?.dismissible ?? true;
  late bool _repeat = _config.message?.repeat ?? false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_disabledMessage, _title, _body, _button, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action().timeout(const Duration(seconds: 15));
      _snack(done);
    } catch (e) {
      _snack('فشل الحفظ: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setEnabled(bool enabled) => _run(
        () => AppConfig.setEnabled(enabled, _disabledMessage.text),
        enabled ? 'تم تشغيل التطبيق.' : 'تم إيقاف التطبيق عند المستخدمين.',
      );

  Future<void> _publish() async {
    if (_body.text.trim().isEmpty) {
      _snack('اكتب نص الرسالة.');
      return;
    }
    // A fresh id makes it show again, even to users who saw the previous one.
    final msg = AppMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      button: _button.text.trim().isEmpty ? 'تمام' : _button.text.trim(),
      url: _url.text.trim(),
      dismissible: _dismissible,
      repeat: _repeat,
    );
    await _run(() => AppConfig.setMessage(msg), 'تم إرسال الرسالة.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('إعدادات التطبيق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: ListenableBuilder(
        listenable: _config,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('تشغيل التطبيق', [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_config.enabled ? 'التطبيق شغّال' : 'التطبيق متوقف عند المستخدمين',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _config.enabled ? AppColors.green : AppColors.blood)),
                subtitle: const Text('الأدمن يبقى قادر يدخل حتى لو التطبيق متوقف.'),
                value: _config.enabled,
                onChanged: _busy ? null : _setEnabled,
              ),
              TextField(
                controller: _disabledMessage,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(labelText: 'الرسالة اللي بتظهر وقت الإيقاف'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : () => _setEnabled(_config.enabled),
                  child: const Text('حفظ نص الإيقاف'),
                ),
              ),
            ]),
            _section('رسالة للمستخدمين', [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('بتظهر للمستخدمين العاديين بعد ما يسجلوا دخول، وما بتظهر للأدمن.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              if (_config.message != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('الرسالة الحالية: ${_config.message!.body}'),
                ),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
              const SizedBox(height: 12),
              TextField(controller: _body, maxLines: 5, minLines: 2, decoration: const InputDecoration(labelText: 'نص الرسالة')),
              const SizedBox(height: 12),
              TextField(controller: _button, decoration: const InputDecoration(labelText: 'نص الزر')),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'رابط يفتحه الزر (اختياري)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('المستخدم يقدر يسكّرها'),
                value: _dismissible,
                onChanged: (v) => setState(() => _dismissible = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تظهر كل ما يفتح التطبيق'),
                subtitle: const Text('بدونها بتظهر مرة وحدة لكل مستخدم.'),
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _publish,
                icon: const Icon(Icons.campaign),
                label: const Text('إرسال الرسالة'),
              ),
              if (_config.message != null)
                TextButton.icon(
                  onPressed: _busy ? null : () => _run(() => AppConfig.setMessage(null), 'تم حذف الرسالة.'),
                  icon: const Icon(Icons.delete, color: AppColors.blood),
                  label: const Text('حذف الرسالة الحالية', style: TextStyle(color: AppColors.blood)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}
