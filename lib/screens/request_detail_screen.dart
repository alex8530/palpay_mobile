import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/registrations_repo.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'requests_screen.dart';

/// Every field of one archived registration, its two photos, and who made it.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.record});

  final RegistrationRecord record;

  // Payload keys in display order, with Arabic labels.
  static const _fields = <String, String>{
    'arabicfullname': 'الاسم بالعربية',
    'fullname': 'الاسم بالإنجليزية',
    'id': 'رقم الهوية',
    'username': 'اسم المستخدم',
    'password': 'كلمة السر',
    'mobile': 'الجوال',
    'email': 'البريد الإلكتروني',
    'dob': 'تاريخ الميلاد',
    'gender': 'الجنس',
    'issuanceCountry': 'دولة الإصدار',
    'nationality': 'الجنسية',
    'country': 'الدولة',
    'region': 'المنطقة',
    'governorate': 'المحافظة',
    'city': 'المدينة',
    'address': 'العنوان',
    'jobTitle': 'المسمى الوظيفي',
    'jobPosition': 'المنصب',
    'incomeRate': 'الدخل',
    'noOtherWallet': 'لا يملك محفظة أخرى',
    'hasBankAccount': 'لديه حساب بنكي',
    'termAccepted': 'وافق على الشروط',
  };

  String _value(String key) {
    final raw = record.data[key];
    if (raw is bool) {
      return raw ? 'نعم' : 'لا';
    }
    final s = (raw ?? '').toString();
    if (key == 'gender') {
      return s == '2' ? 'أنثى' : 'ذكر';
    }
    if (key == 'dob' && s.length >= 10) {
      return s.substring(0, 10);
    }
    final label = record.labels[key];
    return label == null || label.isEmpty ? s : '$label ($s)';
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('تفاصيل الطلب', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_pin, color: AppColors.purpleGlow),
              title: Text('بواسطة: ${r.byName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${r.byPhone}\n${formatDateTime(r.createdAt)}'),
              isThreeLine: true,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: _Photo(registrationId: r.id, which: RegistrationsRepo.imageId, label: 'صورة الهوية')),
                  const SizedBox(width: 12),
                  Expanded(child: _Photo(registrationId: r.id, which: RegistrationsRepo.imagePersonal, label: 'الصورة الشخصية')),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final e in _fields.entries)
                  if (r.data.containsKey(e.key))
                    ListTile(
                      dense: true,
                      title: Text(e.value, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      subtitle: SelectableText(_value(e.key), style: const TextStyle(color: AppColors.text, fontSize: 15)),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'نسخ',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: (r.data[e.key] ?? '').toString()));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ ${e.value}.')));
                        },
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatefulWidget {
  const _Photo({required this.registrationId, required this.which, required this.label});

  final String registrationId, which, label;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late final Future<Uint8List?> _future = RegistrationsRepo.image(widget.registrationId, widget.which);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder<Uint8List?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: EyeLoader(size: 32));
                }
                final bytes = snap.data;
                if (bytes == null) {
                  return const ColoredBox(
                    color: AppColors.surface2,
                    child: Center(child: Text('لا توجد صورة', style: TextStyle(color: AppColors.textFaint))),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(widget.label)),
                      body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
                    ),
                  )),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
