/// Find the first list-of-objects in a response: the transactions/accounts
/// array, whether the response is that list itself or wraps it under some key.
/// Mirrors PalpayController::extractRows().
List<Map<String, dynamic>>? extractRows(dynamic json) {
  if (json is List && json.isNotEmpty && json.first is Map) {
    return json.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
  if (json is Map) {
    for (final value in json.values) {
      if (value is List && value.isNotEmpty && value.first is Map) {
        return value.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    }
  }
  return null;
}

/// Union of column names across all rows, preserving first-seen order.
List<String> columnsFor(List<Map<String, dynamic>>? rows) {
  final columns = <String>[];
  for (final row in rows ?? const []) {
    for (final key in row.keys) {
      if (!columns.contains(key)) {
        columns.add(key);
      }
    }
  }
  return columns;
}
