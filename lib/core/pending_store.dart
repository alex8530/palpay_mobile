import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A registration that was not sent yet (connection dropped, server error, or
/// saved on purpose). Kept on this device until it is sent successfully.
class PendingRequest {
  PendingRequest({
    required this.id,
    required this.owner,
    required this.form,
    required this.updatedAt,
    this.error,
  });

  final String id;

  /// Phone of the user who filled it; each user only sees their own.
  final String owner;

  /// The registration form's fields, as saved by the registration screen.
  final Map<String, dynamic> form;

  final DateTime updatedAt;

  /// Why the last attempt failed, or null if it was only saved.
  final String? error;

  String get title {
    for (final key in ['arabicfullname', 'fullname', 'idNumber']) {
      final v = (form[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'طلب بدون اسم';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner,
        'form': form,
        'updatedAt': updatedAt.toIso8601String(),
        'error': error,
      };

  factory PendingRequest.fromJson(Map<String, dynamic> m) => PendingRequest(
        id: m['id'] as String,
        owner: (m['owner'] ?? '').toString(),
        form: Map<String, dynamic>.from(m['form'] as Map),
        updatedAt: DateTime.tryParse((m['updatedAt'] ?? '').toString()) ?? DateTime.now(),
        error: m['error'] as String?,
      );
}

/// Stores [PendingRequest]s as files in the app's documents folder:
/// `pending/{id}.json` plus `pending/{id}_id.img` and `pending/{id}_personal.img`.
class PendingStore extends ChangeNotifier {
  PendingStore._();

  static final PendingStore instance = PendingStore._();

  @visibleForTesting
  Directory? debugDirectory;

  Future<Directory> _dir() async {
    final base = debugDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}pending');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String name) async => File('${(await _dir()).path}${Platform.pathSeparator}$name');

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// The requests of [owner], most recently changed first.
  Future<List<PendingRequest>> list(String owner) async {
    final dir = await _dir();
    final out = <PendingRequest>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          final r = PendingRequest.fromJson((jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>());
          if (r.owner == owner) out.add(r);
        } catch (_) {
          // Skip a half-written or corrupt file.
        }
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<PendingRequest?> get(String id) async {
    final f = await _file('$id.json');
    if (!await f.exists()) return null;
    return PendingRequest.fromJson((jsonDecode(await f.readAsString()) as Map).cast<String, dynamic>());
  }

  /// Saves (or overwrites) a request with its photos; null photos are removed.
  /// With [writeImages] false the photos on disk are left as they are (for
  /// frequent autosaves where only the text changed).
  Future<void> save(PendingRequest r, {Uint8List? idImage, Uint8List? personalImage, bool writeImages = true}) async {
    if (writeImages) {
      await _writeImage('${r.id}_id.img', idImage);
      await _writeImage('${r.id}_personal.img', personalImage);
    }
    // Write then rename, so a crash mid-write can't leave a broken request.
    final tmp = await _file('${r.id}.json.tmp');
    await tmp.writeAsString(jsonEncode(r.toJson()), flush: true);
    await tmp.rename((await _file('${r.id}.json')).path);
    notifyListeners();
  }

  Future<void> _writeImage(String name, Uint8List? bytes) async {
    final f = await _file(name);
    if (bytes == null) {
      if (await f.exists()) await f.delete();
    } else {
      await f.writeAsBytes(bytes, flush: true);
    }
  }

  Future<(Uint8List?, Uint8List?)> images(String id) async {
    Future<Uint8List?> read(String name) async {
      final f = await _file(name);
      return await f.exists() ? f.readAsBytes() : null;
    }

    return (await read('${id}_id.img'), await read('${id}_personal.img'));
  }

  Future<void> delete(String id) async {
    for (final name in ['$id.json', '${id}_id.img', '${id}_personal.img']) {
      final f = await _file(name);
      if (await f.exists()) await f.delete();
    }
    notifyListeners();
  }
}
