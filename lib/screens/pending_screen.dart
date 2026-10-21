import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/pending_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'registration_screen.dart';
import 'requests_screen.dart';

/// "الطلبات العالقة": registrations saved on this device that weren't sent
/// successfully. Open one to finish, edit and send it again.
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  late Future<List<PendingRequest>> _future = _load();

  Future<List<PendingRequest>> _load() =>
      PendingStore.instance.list(AuthService.instance.user?.phone ?? '');

  void _reload() => setState(() => _future = _load());

  Future<void> _open(PendingRequest r) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegistrationScreen(pendingId: r.id)));
    _reload();
  }

  Future<void> _delete(PendingRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('حذف الطلب؟'),
        content: Text('سيتم حذف "${r.title}" من الطلبات العالقة نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.blood),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PendingStore.instance.delete(r.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('الطلبات العالقة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<List<PendingRequest>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: EyeLoader());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('لا يوجد طلبات عالقة.', style: TextStyle(color: AppColors.textMuted)));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('طلبات ما انبعتت بنجاح. افتح الطلب، عدّل عليه وابعته مرة ثانية.',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              for (final r in list)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.amberBg,
                      child: Icon(Icons.pending_actions, color: AppColors.amber),
                    ),
                    title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((r.form['idNumber'] ?? '').toString().isNotEmpty) Text('هوية: ${r.form['idNumber']}'),
                        Text(r.error ?? 'محفوظ بدون إرسال',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: r.error == null ? AppColors.textMuted : AppColors.blood, fontSize: 12)),
                        Text(formatDateTime(r.updatedAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline, color: AppColors.blood),
                      onPressed: () => _delete(r),
                    ),
                    onTap: () => _open(r),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
