import '../models/request_def.dart';

/// Registry of every PalPay request, ported from `App\Services\Palpay\PalpayRequests`.
/// Keep this file as the single source of truth for the mobile app.
class PalpayRequests {
  static const List<RequestDef> all = [
    // ---------------- الدخول والتفعيل ----------------
    RequestDef(
      key: 'addNewDevice',
      name: 'addNewDevice — تسجيل جهاز جديد',
      group: 'الدخول والتفعيل',
      method: 'POST',
      path: '/api/v1.0/register/addNewDevice',
      signing: 'registration',
      note: 'توقيع فارغ. ACCESS_TOKEN = كود التفعيل. يحفظ passwordSalt في SALT.',
      fields: [
        FieldDef(name: 'mobile', label: 'رقم الموبايل', dir: 'ltr'),
        FieldDef(name: 'username', label: 'اسم المستخدم', from: 'USERNAME', dir: 'ltr'),
      ],
      save: [
        SaveRule(setting: 'SALT', source: 'json', key: 'passwordSalt'),
      ],
    ),
    RequestDef(
      key: 'preActivateAccount',
      name: 'preActivateAccount — ما قبل التفعيل',
      group: 'الدخول والتفعيل',
      method: 'POST',
      path: '/api/v1.0/users/preActivateAccount',
      signing: 'user',
      note: 'Body فارغ {}. ACCESS_TOKEN = كود التفعيل. يحفظ refnum، ويرسل PIN عبر SMS (authType=4).',
      save: [
        SaveRule(setting: 'REFNUM', source: 'json', key: 'refnum'),
      ],
    ),
    RequestDef(
      key: 'activateAccount',
      name: 'activateAccount — التفعيل',
      group: 'الدخول والتفعيل',
      method: 'POST',
      path: '/api/v1.0/users/activateAccount',
      signing: 'user',
      note: 'ACCESS_TOKEN = كود التفعيل. عند النجاح يحفظ token في ACCESS_TOKEN ورقم الحساب في ACCOUNT.',
      fields: [
        FieldDef(name: 'pin', label: 'PIN (من SMS)', dir: 'ltr'),
        FieldDef(name: 'refnum', label: 'refnum', from: 'REFNUM', dir: 'ltr'),
      ],
      save: [
        SaveRule(setting: 'ACCESS_TOKEN', source: 'json', key: 'token'),
        SaveRule(setting: 'ACCOUNT', source: 'json', key: 'accounts.0.accountNumber'),
      ],
    ),
    RequestDef(
      key: 'passwordChange',
      name: 'passwordChange — تغيير كلمة السر (أول دخول)',
      group: 'الدخول والتفعيل',
      method: 'POST',
      path: '/api/v1.0/users/passwordChange',
      signing: 'user',
      note: 'عند النجاح يحفظ passwordSalt الجديد في SALT ويحدّث PASSWORD = newPass.',
      fields: [
        FieldDef(name: 'newPass', label: 'كلمة السر الجديدة', from: 'NEW_PASSWORD', dir: 'ltr'),
        FieldDef(name: 'oldPass', label: 'كلمة السر الحالية', from: 'PASSWORD', dir: 'ltr'),
      ],
      save: [
        SaveRule(setting: 'SALT', source: 'json', key: 'passwordSalt'),
        SaveRule(setting: 'PASSWORD', source: 'input', input: 'newPass'),
      ],
    ),
    RequestDef(
      key: 'authenticate',
      name: 'authenticate — تسجيل الدخول',
      group: 'الدخول والتفعيل',
      method: 'POST',
      path: '/api/v1.0/users/authenticate',
      signing: 'user',
      note: 'Body فارغ {}. يوقّع بـ USERNAME:SALT:PASSWORD. عند النجاح يحفظ token الجديد في ACCESS_TOKEN ورقم الحساب في ACCOUNT.',
      save: [
        SaveRule(setting: 'ACCESS_TOKEN', source: 'json', key: 'token'),
        SaveRule(setting: 'ACCOUNT', source: 'json', key: 'accounts.0.accountNumber'),
      ],
    ),

    // ---------------- الحساب والرصيد ----------------
    RequestDef(
      key: 'getPalPayAccounts',
      name: 'getPalPayAccounts — عرض الرصيد',
      group: 'الحساب والرصيد',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/getPalPayAccounts',
      signing: 'user',
      note: 'يرجع مصفوفة الحسابات. يحفظ رقم حساب الشيكل (curCode 376) في FROM_ACCOUNT.',
      fields: [
        FieldDef(name: 'account', label: 'رقم الحساب', from: 'ACCOUNT', dir: 'ltr'),
      ],
      save: [
        SaveRule(
          setting: 'FROM_ACCOUNT',
          source: 'array_find',
          match: {'curCode': 376},
          key: 'accountNumber',
        ),
      ],
    ),
    RequestDef(
      key: 'ministatement',
      name: 'ministatement — كشف مصغّر',
      group: 'الحساب والرصيد',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/ministatement',
      signing: 'user',
      note: 'account = حساب الشيكل (FROM_ACCOUNT) من getPalPayAccounts، وليس رقم الحساب الرئيسي.',
      fields: [
        FieldDef(name: 'account', label: 'رقم الحساب (شيكل)', from: 'FROM_ACCOUNT', dir: 'ltr'),
      ],
    ),
    RequestDef(
      key: 'transfersHistory',
      name: 'transfersHistory — سجل التحويلات',
      group: 'الحساب والرصيد',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/transfersHistory',
      signing: 'user',
      note: 'account = حساب الشيكل (FROM_ACCOUNT) من getPalPayAccounts. from/to بصيغة yyyy-MM-dd. type: 0=الكل 1=بين الحسابات 2=لصديق 3=لتاجر 4=شحن 5=فواتير 6=سحب.',
      fields: [
        FieldDef(name: 'account', label: 'رقم الحساب (شيكل)', from: 'FROM_ACCOUNT', dir: 'ltr'),
        FieldDef(name: 'from', label: 'من تاريخ', type: 'date', defaultValue: '2026-01-01'),
        FieldDef(name: 'to', label: 'إلى تاريخ', type: 'date', defaultValue: '2026-12-31'),
        FieldDef(
          name: 'type',
          label: 'النوع',
          type: 'select',
          cast: 'int',
          defaultValue: '0',
          options: {
            '0': 'الجميع',
            '1': 'بين الحسابات',
            '2': 'لصديق',
            '3': 'لتاجر',
            '4': 'شحن أرصدة',
            '5': 'فواتير',
            '6': 'سحب نقدي',
          },
        ),
      ],
    ),
    RequestDef(
      key: 'confirmWalletAddBalance',
      name: 'confirmWalletAddBalance — شحن رصيد',
      group: 'الحساب والرصيد',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/confirmWalletAddBalance',
      signing: 'user',
      note: 'qrCode من مسح كود الوكيل. ⚠️ يؤثر على الرصيد فعلياً عند النجاح.',
      fields: [
        FieldDef(name: 'qrCode', label: 'qrCode', type: 'textarea', dir: 'ltr'),
        FieldDef(name: 'refCode', label: 'refCode', dir: 'ltr'),
      ],
    ),

    // ---------------- التحويل لصديق ----------------
    RequestDef(
      key: 'checkPayToFriendAccount',
      name: 'checkPayToFriendAccount — التحقق من المستلم',
      group: 'التحويل لصديق',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/checkPayToFriendAccount',
      signing: 'user',
      note: 'يحفظ clientFullName في TO_NAME و destinationCode في DEST_CODE.',
      fields: [
        FieldDef(name: 'bankNumber', label: 'bankNumber', defaultValue: '89', dir: 'ltr'),
        FieldDef(name: 'mobileNumber', label: 'موبايل المستلم', dir: 'ltr'),
        FieldDef(name: 'useSwitch', label: 'useSwitch', type: 'checkbox', cast: 'bool', defaultValue: '1'),
        FieldDef(name: 'destinationCode', label: 'destinationCode', defaultValue: '', dir: 'ltr'),
      ],
      save: [
        SaveRule(setting: 'TO_NAME', source: 'array_first', key: 'clientFullName'),
        SaveRule(setting: 'DEST_CODE', source: 'array_first', key: 'destinationCode'),
      ],
    ),
    RequestDef(
      key: 'prePayToFriendTransfer',
      name: 'prePayToFriendTransfer — تجهيز التحويل',
      group: 'التحويل لصديق',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/prePayToFriendTransfer',
      signing: 'user',
      note: 'fromAccount = حساب الشيكل من getPalPayAccounts. ⚠️ يرسل PIN ويبدأ تحويل مال فعلي.',
      fields: [
        FieldDef(name: 'fromAccount', label: 'fromAccount (شيكل)', from: 'FROM_ACCOUNT', dir: 'ltr'),
        FieldDef(name: 'mobileNumber', label: 'موبايل المستلم', dir: 'ltr'),
        FieldDef(name: 'amount', label: 'المبلغ', type: 'number', cast: 'float', defaultValue: '1'),
        FieldDef(name: 'description', label: 'الوصف', defaultValue: 'transfer'),
        FieldDef(name: 'toName', label: 'اسم المستلم', from: 'TO_NAME'),
        FieldDef(name: 'destinationCode', label: 'destinationCode', from: 'DEST_CODE', dir: 'ltr'),
      ],
      save: [
        SaveRule(setting: 'TRANSFER_ID', source: 'json', key: 'transferId'),
        SaveRule(setting: 'TRANSFER_TOKEN', source: 'json', key: 'transferToken'),
        SaveRule(setting: 'TR_REFNUM', source: 'json', key: 'refnum'),
      ],
    ),
    RequestDef(
      key: 'confirmPayToFriendTransfer',
      name: 'confirmPayToFriendTransfer — تأكيد التحويل',
      group: 'التحويل لصديق',
      method: 'POST',
      path: '/api/v1.0/palpayaccount/confirmPayToFriendTransfer',
      signing: 'user',
      note: '⚠️ يُنفّذ التحويل فعلياً. pin من SMS.',
      fields: [
        FieldDef(name: 'pin', label: 'PIN (من SMS)', dir: 'ltr'),
        FieldDef(name: 'transferId', label: 'transferId', from: 'TRANSFER_ID', dir: 'ltr'),
        FieldDef(name: 'transferToken', label: 'transferToken', from: 'TRANSFER_TOKEN', dir: 'ltr'),
        FieldDef(name: 'refnum', label: 'refnum', from: 'TR_REFNUM', dir: 'ltr'),
        FieldDef(name: 'toName', label: 'اسم المستلم', from: 'TO_NAME'),
        FieldDef(name: 'destinationCode', label: 'destinationCode', from: 'DEST_CODE', dir: 'ltr'),
      ],
    ),
  ];

  static RequestDef? find(String key) {
    for (final def in all) {
      if (def.key == key) {
        return def;
      }
    }
    return null;
  }

  /// Requests grouped by their 'group' label, preserving order.
  static Map<String, List<RequestDef>> grouped() {
    final map = <String, List<RequestDef>>{};
    for (final def in all) {
      map.putIfAbsent(def.group, () => []).add(def);
    }
    return map;
  }
}
