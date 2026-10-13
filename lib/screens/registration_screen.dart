import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/enroll_config.dart';
import '../core/lookups.dart';
import '../core/registration_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';

/// "التسجيل": fill the form, attach the two images, and register immediately
/// (no admin approval) by running PreEnroll → EnrollInMobileBanking →
/// resendActivationInfo — the exact same flow as the web project.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();

  final _idNumber = TextEditingController();
  final _username = TextEditingController();
  final _fullname = TextEditingController();
  final _arabicfullname = TextEditingController();
  final _password = TextEditingController(text: EnrollConfig.defaultPassword);
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController(text: EnrollConfig.defaultAddress);
  final _incomeRate = TextEditingController();

  String _gender = '1';
  int? _dobDay, _dobMonth, _dobYear;

  String? _issuanceCountry = EnrollConfig.defaultCountry;
  String? _nationality = EnrollConfig.defaultCountry;
  String? _country = EnrollConfig.defaultCountry;
  String? _region;
  String? _governorate;
  String? _city;
  String? _jobTitle;
  String? _jobPosition;

  Uint8List? _idBytes, _personalBytes;

  bool _noOtherWallet = true;
  bool _hasBankAccount = false;
  bool _termAccepted = false;

  final _futures = <String, Future<List<LookupOption>>>{};
  bool _submitting = false;
  RegistrationResult? _result;
  String? _formError;
  bool _emailEdited = false;

  static const _months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _idNumber.addListener(_syncFromId);
    _email.addListener(() {
      if (_email.text.isNotEmpty && _email.text != _suggestedEmail) _emailEdited = true;
    });
  }

  String get _suggestedEmail =>
      _idNumber.text.trim().isEmpty ? '' : '${_idNumber.text.trim()}@${EnrollConfig.emailDomain}';

  void _syncFromId() {
    final id = _idNumber.text.trim();
    _username.text = id;
    if (!_emailEdited) {
      _email.text = id.isEmpty ? '' : '$id@${EnrollConfig.emailDomain}';
    }
    setState(() {}); // refresh the readonly username display
  }

  @override
  void dispose() {
    for (final c in [_idNumber, _username, _fullname, _arabicfullname, _password, _mobile, _email, _address, _incomeRate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<LookupOption>> _future(String type, String? parent) {
    return _futures.putIfAbsent('$type:${parent ?? ''}', () => Lookups.options(type, parent));
  }

  // -------------------------------------------------------------- submit

  Future<void> _submit() async {
    setState(() => _formError = null);
    final problems = <String>[];
    if (!(_form.currentState?.validate() ?? false)) {
      problems.add('أكمل الحقول المطلوبة');
    }
    if (_idBytes == null || _personalBytes == null) problems.add('أرفق صورة الهوية والصورة الشخصية');
    if (_dobDay == null || _dobMonth == null || _dobYear == null) problems.add('اختر تاريخ الميلاد');
    for (final v in [_issuanceCountry, _nationality, _country, _region, _governorate, _city, _jobTitle, _jobPosition]) {
      if (v == null || v.isEmpty) {
        problems.add('أكمل قوائم الدولة/المنطقة/المحافظة/المدينة والعمل');
        break;
      }
    }
    if (!_termAccepted) problems.add('يجب الموافقة على الشروط والأحكام');

    String? dob;
    if (_dobDay != null && _dobMonth != null && _dobYear != null) {
      dob = '${_dobYear.toString().padLeft(4, '0')}-${_dobMonth.toString().padLeft(2, '0')}-${_dobDay.toString().padLeft(2, '0')}';
      if (!DateTime.parse(dob).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
        problems.add('تاريخ الميلاد يجب أن يكون قبل اليوم');
      }
    }

    if (problems.isNotEmpty) {
      setState(() => _formError = problems.join('. '));
      return;
    }

    final data = RegistrationData(
      fullname: _fullname.text.trim(),
      arabicfullname: _arabicfullname.text.trim(),
      username: _idNumber.text.trim(),
      password: _password.text,
      mobile: _mobile.text.trim(),
      email: _email.text.trim(),
      placeOfBirth: dob!,
      gender: _gender,
      idNumber: _idNumber.text.trim(),
      issuanceCountry: _issuanceCountry!,
      nationality: _nationality!,
      country: _country!,
      region: _region!,
      governorate: _governorate!,
      city: _city!,
      address: _address.text.trim(),
      jobTitle: _jobTitle!,
      jobPosition: _jobPosition!,
      incomeRate: _incomeRate.text.trim(),
      termAccepted: _termAccepted,
      noOtherWallet: _noOtherWallet,
      hasBankAccount: _hasBankAccount,
    );

    setState(() {
      _submitting = true;
      _result = null;
    });
    RegistrationResult result;
    try {
      result = await RegistrationService().run(data, _idBytes!, _personalBytes!);
    } catch (e) {
      result = RegistrationResult(ok: false, message: 'خطأ غير متوقع: $e', log: const []);
    }
    if (mounted) {
      setState(() {
        _result = result;
        _submitting = false;
      });
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('التسجيل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: staggered([
            _identityCard(),
            _personalCard(),
            _accountCard(),
            _addressWorkCard(),
            if (_formError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bloodBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blood)),
                child: Text(_formError!, style: const TextStyle(color: AppColors.blood)),
              ),
            PressScale(
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: EyeLoader(size: 20))
                    : const Text('إرسال الطلب والتسجيل'),
              ),
            ),
            if (_result != null) _resultCard(_result!),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- cards

  Widget _identityCard() {
    return _card('الهوية والصور', [
      _text(_idNumber, 'رقم الهوية', ltr: true, keyboard: TextInputType.number, validator: (v) {
        final s = (v ?? '').trim();
        if (!RegExp(r'^\d{5,20}$').hasMatch(s)) return 'رقم هوية غير صحيح';
        return null;
      }),
      _imagePicker('صورة الهوية', _idBytes, () => _pick(true)),
      _imagePicker('صورة شخصية', _personalBytes, () => _pick(false),
          warning: '⚠️ صورة سيلفي للوجه فقط — لا تضع بطاقة الهوية أو أي صورة فيها وجه داخل الكادر (وجهان في الصورة يسبّبان فشل التسجيل).'),
    ]);
  }

  Widget _personalCard() {
    return _card('المعلومات الشخصية', [
      _text(_fullname, 'الاسم الكامل بالإنجليزية', ltr: true, validator: _required),
      _text(_arabicfullname, 'الاسم الكامل بالعربية', validator: _required),
      _dobField(),
      _field('الجنس', DropdownButtonFormField<String>(
        value: _gender,
        items: const [
          DropdownMenuItem(value: '1', child: Text('ذكر')),
          DropdownMenuItem(value: '2', child: Text('أنثى')),
        ],
        onChanged: (v) => setState(() => _gender = v ?? '1'),
      )),
      _lookup('دولة الإصدار', 'countries', _issuanceCountry, (v) => setState(() => _issuanceCountry = v)),
      _lookup('الجنسية', 'countries', _nationality, (v) => setState(() => _nationality = v)),
    ]);
  }

  Widget _accountCard() {
    return _card('معلومات الحساب والتواصل', [
      _text(_username, 'اسم المستخدم (= رقم الهوية)', ltr: true, readOnly: true),
      _text(_password, 'كلمة المرور', ltr: true, obscure: true, validator: (v) {
        if ((v ?? '').length < 8) return 'كلمة المرور 8 أحرف على الأقل';
        return null;
      }),
      _text(_mobile, 'رقم الجوال', ltr: true, keyboard: TextInputType.phone, hint: '05XXXXXXXX', validator: (v) {
        if (!RegExp(r'^05\d{8}$').hasMatch((v ?? '').trim())) return 'رقم الجوال يجب أن يبدأ بـ 05 ويتكون من 10 أرقام';
        return null;
      }),
      _text(_email, 'البريد الإلكتروني', ltr: true, keyboard: TextInputType.emailAddress, validator: (v) {
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())) return 'بريد إلكتروني غير صحيح';
        return null;
      }),
    ]);
  }

  Widget _addressWorkCard() {
    return _card('العنوان والعمل', [
      _lookup('الدولة', 'countries', _country, (v) => setState(() => _country = v)),
      _lookup('المنطقة', 'regions', _region, (v) => setState(() {
        _region = v;
        _governorate = null;
        _city = null;
      })),
      _lookup('المحافظة', 'governorates', _governorate, (v) => setState(() {
        _governorate = v;
        _city = null;
      }), parent: _region),
      _lookup('المدينة', 'cities', _city, (v) => setState(() => _city = v), parent: _governorate),
      _text(_address, 'العنوان', validator: _required),
      _lookup('المسمى الوظيفي', 'job_titles', _jobTitle, (v) => setState(() {
        _jobTitle = v;
        _jobPosition = null;
      })),
      _lookup('المنصب', 'job_positions', _jobPosition, (v) => setState(() => _jobPosition = v), parent: _jobTitle),
      _text(_incomeRate, 'معدل الدخل (اختياري)'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _noOtherWallet,
        onChanged: (v) => setState(() => _noOtherWallet = v ?? false),
        title: const Text('لا أملك محفظة أخرى'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _hasBankAccount,
        onChanged: (v) => setState(() => _hasBankAccount = v ?? false),
        title: const Text('لدي حساب بنكي'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _termAccepted,
        onChanged: (v) => setState(() => _termAccepted = v ?? false),
        title: const Text('أوافق على الشروط والأحكام'),
      ),
    ]);
  }

  // ---------------------------------------------------------------- result

  Widget _resultCard(RegistrationResult r) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(r.ok ? Icons.check_circle : Icons.error, color: r.ok ? AppColors.green : AppColors.blood),
              const SizedBox(width: 8),
              Expanded(child: Text(r.message, style: TextStyle(fontWeight: FontWeight.bold, color: r.ok ? AppColors.green : AppColors.blood))),
            ]),
            if (r.log.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('سجل الاتصال بخادم التسجيل', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final step in r.log) _stepTile(step),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepTile(RegistrationStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: step.ok ? AppColors.green : AppColors.blood),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(step.step, style: const TextStyle(fontWeight: FontWeight.w700))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: step.ok ? AppColors.greenBg : AppColors.bloodBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(step.ok ? 'نجاح' : 'فشل ${step.status ?? ''}',
                  style: TextStyle(fontSize: 11, color: step.ok ? AppColors.green : AppColors.blood)),
            ),
          ]),
          if (step.reason != null) ...[
            const SizedBox(height: 4),
            Text(step.reason!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- widgets

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null;

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: InputBorder.none, contentPadding: EdgeInsets.zero),
        child: child,
      ),
    );
  }

  Widget _text(TextEditingController c, String label,
      {bool ltr = false,
      bool obscure = false,
      bool readOnly = false,
      String? hint,
      TextInputType? keyboard,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboard,
        textDirection: ltr ? TextDirection.ltr : null,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
      ),
    );
  }

  Widget _dobField() {
    Widget sel<T>(String hint, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
      return Expanded(
        child: DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, overflow: TextOverflow.ellipsis),
          items: items,
          onChanged: onChanged,
          decoration: const InputDecoration(isDense: true),
        ),
      );
    }

    final now = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('تاريخ الميلاد', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Row(children: [
            sel('اليوم', _dobDay, [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))], (v) => setState(() => _dobDay = v)),
            const SizedBox(width: 8),
            sel('الشهر', _dobMonth, [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text('$m - ${_months[m - 1]}'))], (v) => setState(() => _dobMonth = v)),
            const SizedBox(width: 8),
            sel('السنة', _dobYear, [for (var y = now; y >= 1930; y--) DropdownMenuItem(value: y, child: Text('$y'))], (v) => setState(() => _dobYear = v)),
          ]),
        ],
      ),
    );
  }

  Widget _lookup(String label, String type, String? value, ValueChanged<String?> onChanged, {String? parent}) {
    final def = EnrollConfig.lookups[type];
    final needsParent = def != null && def['parent'] != null;
    if (needsParent && (parent == null || parent.isEmpty)) {
      return _field(label, const Text('اختر القائمة السابقة أولاً', style: TextStyle(color: AppColors.textFaint)));
    }
    return FutureBuilder<List<LookupOption>>(
      // The label keeps the key unique when one list backs several fields
      // (issuance country / nationality / country); the parent resets it.
      key: ValueKey('$label|$type:${parent ?? ''}'),
      future: _future(type, parent),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _field(label, const Row(children: [EyeLoader(size: 18), SizedBox(width: 8), Text('جارٍ التحميل...', style: TextStyle(color: AppColors.textMuted))]));
        }
        if (snap.hasError) {
          return _field(label, Row(children: [
            const Expanded(child: Text('تعذر تحميل القائمة', style: TextStyle(color: AppColors.blood))),
            TextButton(onPressed: () => setState(() => _futures.remove('$type:${parent ?? ''}')), child: const Text('إعادة')),
          ]));
        }
        final opts = snap.data!;
        final current = opts.any((o) => o.id == value) ? value : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: current,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [for (final o in opts) DropdownMenuItem(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis))],
            onChanged: onChanged,
          ),
        );
      },
    );
  }

  Widget _imagePicker(String label, Uint8List? bytes, VoidCallback onTap, {String? warning}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          PressScale(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.purpleTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: bytes == null
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_a_photo, color: AppColors.purpleGlow, size: 30),
                        SizedBox(height: 6),
                        Text('اضغط لاختيار صورة', style: TextStyle(color: AppColors.textMuted)),
                      ]))
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
          ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(warning, style: const TextStyle(fontSize: 12, color: AppColors.amber)),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(bool isId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('الكاميرا'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('المعرض'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2600, imageQuality: 92);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      if (isId) {
        _idBytes = bytes;
      } else {
        _personalBytes = bytes;
      }
    });
  }
}
