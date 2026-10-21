import 'package:cloud_firestore/cloud_firestore.dart' show QuerySnapshot;
import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'requests_screen.dart';

/// Admin: list, add, edit, disable and delete app users (`users/{phone}`).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('المستخدمين', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة مستخدم'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuthService.users.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('تعذّر تحميل المستخدمين:\n${snap.error}', textAlign: TextAlign.center));
          }
          if (!snap.hasData) {
            return const Center(child: EyeLoader());
          }
          final users = snap.data!.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
            ..sort((a, b) {
              if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
              return a.name.compareTo(b.name);
            });
          if (users.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمين.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [for (final u in users) _tile(context, u)],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, AppUser u) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: u.active ? AppColors.purpleDeep : AppColors.bloodBg,
          child: Icon(u.isAdmin ? Icons.shield : Icons.person, color: u.active ? AppColors.purpleGlow : AppColors.blood),
        ),
        title: Text(u.name.isEmpty ? u.phone : u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text([
          u.phone,
          if (u.isAdmin) 'أدمن',
          if (!u.active) 'موقوف',
        ].join('  •  ')),
        trailing: IconButton(
          tooltip: 'طلباته',
          icon: const Icon(Icons.assignment, color: AppColors.purpleGlow),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RequestsScreen(byPhone: u.phone, title: 'طلبات ${u.name.isEmpty ? u.phone : u.name}'),
          )),
        ),
        onTap: () => _edit(context, u),
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppUser? user) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserForm(user: user),
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final AppUser? user; // null = new user

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late final _phone = TextEditingController(text: widget.user?.phone);
  late final _name = TextEditingController(text: widget.user?.name);
  late final _password = TextEditingController(text: widget.user?.password);
  late bool _admin = widget.user?.isAdmin ?? false;
  late bool _active = widget.user?.active ?? true;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.user == null;
  bool get _isMe => widget.user?.phone == AuthService.instance.user?.phone;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = AuthService.normalizePhone(_phone.text);
    final name = _name.text.trim();
    final password = _password.text;
    if (phone.length < 6 || name.isEmpty || password.isEmpty) {
      setState(() => _error = 'اكتب رقم جوال صحيح والاسم وكلمة السر.');
      return;
    }
    if (password.length < AuthService.minPasswordLength) {
      setState(() => _error = 'كلمة السر لازم تكون ${AuthService.minPasswordLength} أحرف على الأقل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final updated = AppUser(phone: phone, name: name, password: password, role: _admin ? 'admin' : 'user', active: _active);
    try {
      if (_isNew) {
        await UserAdmin.create(updated).timeout(const Duration(seconds: 30));
      } else {
        if (_isMe) {
          AuthService.instance.adoptOwnChanges(updated);
        }
        await UserAdmin.update(widget.user!, updated).timeout(const Duration(seconds: 30));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (_isMe) {
        AuthService.instance.adoptOwnChanges(widget.user!); // put the old values back
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is String ? e : 'فشل الحفظ: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('حذف المستخدم؟'),
        content: Text('سيتم حذف ${widget.user!.name} (${widget.user!.phone}). طلباته السابقة تبقى محفوظة.'),
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
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await UserAdmin.delete(widget.user!).timeout(const Duration(seconds: 30));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is String ? e : 'فشل الحذف: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isNew ? 'مستخدم جديد' : 'تعديل المستخدم',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              enabled: _isNew, // the phone is the document id
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الجوال'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة السر'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('أدمن (صلاحيات كاملة)'),
              value: _admin,
              // Don't let the admin demote or lock themselves out.
              onChanged: _isMe ? null : (v) => setState(() => _admin = v),
            ),
            SwitchListTile(
              title: const Text('الحساب فعّال'),
              value: _active,
              onChanged: _isMe ? null : (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.blood)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy ? const SizedBox(height: 20, width: 20, child: EyeLoader(size: 20)) : const Text('حفظ'),
              ),
            ),
            if (!_isNew && !_isMe)
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete, color: AppColors.blood),
                label: const Text('حذف المستخدم', style: TextStyle(color: AppColors.blood)),
              ),
          ],
        ),
      ),
    );
  }
}
