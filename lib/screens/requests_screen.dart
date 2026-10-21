import 'package:flutter/material.dart';

import '../core/registrations_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'request_detail_screen.dart';

/// Archived registrations: all of them (admin) or those made by [byPhone].
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, this.byPhone, this.title = 'طلبات التسجيل'});

  final String? byPhone;
  final String title;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late final Stream<List<RegistrationRecord>> _stream = RegistrationsRepo.watch(byPhone: widget.byPhone);
  String _query = '';

  bool _matches(RegistrationRecord r) {
    if (_query.isEmpty) {
      return true;
    }
    final haystack = [
      r.field('arabicfullname'),
      r.field('fullname'),
      r.field('id'),
      r.field('mobile'),
      r.byName,
      r.byPhone,
    ].join(' ').toLowerCase();
    return haystack.contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FlickerText(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<List<RegistrationRecord>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _centered('تعذّر تحميل الطلبات:\n${snap.error}', color: AppColors.blood);
          }
          if (!snap.hasData) {
            return const Center(child: EyeLoader());
          }
          final all = snap.data!;
          final list = all.where(_matches).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'بحث بالاسم، الهوية، الجوال أو المستخدم',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 8),
              Text('${list.length} من ${all.length} طلب', style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              if (all.isEmpty) _centered('لا يوجد طلبات بعد.'),
              for (final r in list) _tile(r),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(RegistrationRecord r) {
    final name = r.field('arabicfullname').isNotEmpty ? r.field('arabicfullname') : r.field('fullname');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.purpleDeep,
          child: Icon(Icons.badge, color: AppColors.purpleGlow),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هوية: ${r.field('id')}  •  جوال: ${r.field('mobile')}'),
            if (widget.byPhone == null) Text('بواسطة: ${r.byName} (${r.byPhone})', style: const TextStyle(color: AppColors.purpleGlow)),
            Text(formatDateTime(r.createdAt), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: AppColors.purpleGlow),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RequestDetailScreen(record: r)),
        ),
      ),
    );
  }

  Widget _centered(String text, {Color color = AppColors.textMuted}) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color))),
      );
}

/// "2026-10-21 14:05", or a placeholder while the server time is pending.
String formatDateTime(DateTime? d) {
  if (d == null) {
    return 'قيد الحفظ...';
  }
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
