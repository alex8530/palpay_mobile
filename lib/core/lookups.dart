import 'enroll_client.dart';
import 'enroll_config.dart';

class LookupOption {
  const LookupOption(this.id, this.name);
  final String id;
  final String name;
}

/// Option lists for the registration dropdowns — ported from LookupService.
/// Regions are a fixed list; the rest come from the info API and are cached.
class Lookups {
  static final _client = EnrollClient();
  static final _cache = <String, List<LookupOption>>{};

  static List<LookupOption> regions() =>
      EnrollConfig.regions.entries.map((e) => LookupOption(e.key, e.value)).toList();

  static Future<List<LookupOption>> options(String type, [String? parent]) async {
    if (type == 'regions') {
      return regions();
    }
    final def = EnrollConfig.lookups[type]!;
    final parentKey = def['parent'];
    if (parentKey != null && (parent == null || parent.isEmpty)) {
      return const [];
    }
    final cacheKey = '$type:${parent ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final query = parentKey != null ? {parentKey: parent!} : <String, String>{};
    final items = await _client.getLookup(def['path']!, query);
    final opts = [for (final m in items) LookupOption(m['id']!, m['name']!)];
    _cache[cacheKey] = opts;
    return opts;
  }
}
