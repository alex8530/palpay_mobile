import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// A successful registration archived in Firestore at `registrations/{id}`.
/// The two photos live in `registrations/{id}/images/{id|personal}`, one per
/// document, so each stays under Firestore's 1 MiB document limit.
class RegistrationRecord {
  RegistrationRecord({
    required this.id,
    required this.data,
    required this.labels,
    required this.byPhone,
    required this.byName,
    this.createdAt,
  });

  final String id;

  /// The exact EnrollInMobileBanking payload that was sent.
  final Map<String, dynamic> data;

  /// Display names of the code fields (country, city, job...), keyed like [data].
  final Map<String, String> labels;

  final String byPhone, byName;
  final DateTime? createdAt;

  String field(String key) => (data[key] ?? '').toString();

  factory RegistrationRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return RegistrationRecord(
      id: doc.id,
      data: Map<String, dynamic>.from(m['data'] as Map? ?? const {}),
      labels: (m['labels'] as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      byPhone: (m['byPhone'] ?? '').toString(),
      byName: (m['byName'] ?? '').toString(),
      createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
    );
  }
}

class RegistrationsRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('registrations');

  static const imageId = 'id';
  static const imagePersonal = 'personal';

  /// Saves one registration with its two photos in a single batch.
  static Future<void> save({
    required Map<String, dynamic> data,
    required Map<String, String> labels,
    required String idImageBase64,
    required String personalImageBase64,
    required AppUser by,
  }) {
    final doc = _col.doc();
    final batch = FirebaseFirestore.instance.batch()
      ..set(doc, {
        'data': data,
        'labels': labels,
        'byPhone': by.phone,
        'byName': by.name,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(doc.collection('images').doc(imageId), {'bytes': Blob(base64Decode(idImageBase64))})
      ..set(doc.collection('images').doc(imagePersonal), {'bytes': Blob(base64Decode(personalImageBase64))});
    return batch.commit();
  }

  /// Every registration (admin), or only those made by [byPhone], newest first.
  static Stream<List<RegistrationRecord>> watch({String? byPhone}) {
    // Filtering without orderBy avoids needing a composite index; sort here.
    final Query<Map<String, dynamic>> q =
        byPhone == null ? _col.orderBy('createdAt', descending: true) : _col.where('byPhone', isEqualTo: byPhone);
    return q.snapshots().map((snap) {
      final list = snap.docs.map(RegistrationRecord.fromDoc).toList();
      final far = DateTime(9999);
      list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
      return list;
    });
  }

  static Future<Uint8List?> image(String registrationId, String which) async {
    final doc = await _col.doc(registrationId).collection('images').doc(which).get();
    final bytes = doc.data()?['bytes'];
    return bytes is Blob ? bytes.bytes : null;
  }
}
