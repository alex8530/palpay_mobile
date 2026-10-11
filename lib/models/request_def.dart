/// A single body field in a request form.
class FieldDef {
  const FieldDef({
    required this.name,
    required this.label,
    this.from,
    this.defaultValue,
    this.type = 'text', // text | textarea | select | checkbox | number | date
    this.cast = 'string', // string | int | float | bool
    this.dir = 'rtl',
    this.options,
  });

  final String name;
  final String label;
  final String? from; // prefill from a setting key
  final String? defaultValue;
  final String type;
  final String cast;
  final String dir;
  final Map<String, String>? options; // for select
}

/// A rule applied to the JSON response to auto-save a value into settings.
class SaveRule {
  const SaveRule({
    required this.setting,
    required this.source, // json | array_first | array_find | input
    this.key,
    this.input,
    this.match,
  });

  final String setting;
  final String source;
  final String? key; // dotted path for 'json', field name for the array sources
  final String? input; // input field name for 'input'
  final Map<String, Object?>? match; // for array_find
}

/// A full request definition (signing + form + save rules).
class RequestDef {
  const RequestDef({
    required this.key,
    required this.name,
    required this.group,
    required this.method,
    required this.path,
    required this.signing, // user | registration
    this.note,
    this.fields = const [],
    this.save = const [],
  });

  final String key;
  final String name;
  final String group;
  final String method;
  final String path;
  final String signing;
  final String? note;
  final List<FieldDef> fields;
  final List<SaveRule> save;
}
