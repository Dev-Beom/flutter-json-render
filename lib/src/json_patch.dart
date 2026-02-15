import 'json_path.dart';

enum JsonPatchOp { add, remove, replace, move, copy, test }

class JsonPatchOperation {
  const JsonPatchOperation({
    required this.op,
    required this.path,
    this.value,
    this.from,
  });

  final JsonPatchOp op;
  final String path;
  final dynamic value;
  final String? from;

  factory JsonPatchOperation.fromJson(Map<String, dynamic> json) {
    final rawOp = json['op']?.toString() ?? '';
    final op = _parsePatchOp(rawOp);
    if (op == null) {
      throw FormatException('Unsupported patch op: "$rawOp".');
    }

    final path = json['path']?.toString() ?? '';
    if (path.isEmpty) {
      throw const FormatException('Patch operation requires a non-empty path.');
    }

    return JsonPatchOperation(
      op: op,
      path: path,
      value: json['value'],
      from: json['from']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'op': op.name,
      'path': path,
      if (from != null) 'from': from,
      if (op == JsonPatchOp.add ||
          op == JsonPatchOp.replace ||
          op == JsonPatchOp.test)
        'value': value,
    };
  }
}

Map<String, dynamic> applyJsonPatch(
  Map<String, dynamic> document,
  List<JsonPatchOperation> operations,
) {
  var next = _deepCopyMap(document);

  for (final operation in operations) {
    switch (operation.op) {
      case JsonPatchOp.add:
        next = _add(next, operation.path, _deepCopy(operation.value));
      case JsonPatchOp.remove:
        next = _remove(next, operation.path);
      case JsonPatchOp.replace:
        next = _replace(next, operation.path, _deepCopy(operation.value));
      case JsonPatchOp.move:
        next = _move(next, operation);
      case JsonPatchOp.copy:
        next = _copy(next, operation);
      case JsonPatchOp.test:
        _test(next, operation);
    }
  }

  return next;
}

Map<String, dynamic> _add(
  Map<String, dynamic> document,
  String path,
  dynamic value,
) {
  if (path == '/') {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Replacing root requires an object value.');
    }
    return _deepCopyMap(value);
  }

  final segments = parsePath(path);
  if (segments.isEmpty) {
    throw const FormatException('Patch path must not be empty.');
  }

  final parent = _traverse(
    document,
    segments.take(segments.length - 1).toList(),
  );
  final token = segments.last;

  if (parent is Map<String, dynamic>) {
    parent[token] = value;
    return document;
  }

  if (parent is List) {
    if (token == '-') {
      parent.add(value);
      return document;
    }

    final index = int.tryParse(token);
    if (index == null || index < 0 || index > parent.length) {
      throw FormatException('Invalid add index "$token" in path "$path".');
    }
    parent.insert(index, value);
    return document;
  }

  throw FormatException('Cannot apply add at path "$path".');
}

Map<String, dynamic> _remove(Map<String, dynamic> document, String path) {
  final segments = parsePath(path);
  if (segments.isEmpty) {
    throw const FormatException('Removing root document is not supported.');
  }

  final parent = _traverse(
    document,
    segments.take(segments.length - 1).toList(),
  );
  final token = segments.last;

  if (parent is Map<String, dynamic>) {
    if (!parent.containsKey(token)) {
      throw FormatException('Path "$path" does not exist.');
    }
    parent.remove(token);
    return document;
  }

  if (parent is List) {
    final index = int.tryParse(token);
    if (index == null || index < 0 || index >= parent.length) {
      throw FormatException('Invalid remove index "$token" in path "$path".');
    }
    parent.removeAt(index);
    return document;
  }

  throw FormatException('Cannot apply remove at path "$path".');
}

Map<String, dynamic> _replace(
  Map<String, dynamic> document,
  String path,
  dynamic value,
) {
  final segments = parsePath(path);
  if (segments.isEmpty) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Replacing root requires an object value.');
    }
    return _deepCopyMap(value);
  }

  final parent = _traverse(
    document,
    segments.take(segments.length - 1).toList(),
  );
  final token = segments.last;

  if (parent is Map<String, dynamic>) {
    if (!parent.containsKey(token)) {
      throw FormatException('Path "$path" does not exist for replace.');
    }
    parent[token] = value;
    return document;
  }

  if (parent is List) {
    final index = int.tryParse(token);
    if (index == null || index < 0 || index >= parent.length) {
      throw FormatException('Invalid replace index "$token" in path "$path".');
    }
    parent[index] = value;
    return document;
  }

  throw FormatException('Cannot apply replace at path "$path".');
}

Map<String, dynamic> _move(
  Map<String, dynamic> document,
  JsonPatchOperation operation,
) {
  final from = operation.from;
  if (from == null || from.isEmpty) {
    throw const FormatException('Move operation requires `from`.');
  }

  final sourceValue = _deepCopy(_read(document, from));
  final removed = _remove(document, from);
  return _add(removed, operation.path, sourceValue);
}

Map<String, dynamic> _copy(
  Map<String, dynamic> document,
  JsonPatchOperation operation,
) {
  final from = operation.from;
  if (from == null || from.isEmpty) {
    throw const FormatException('Copy operation requires `from`.');
  }

  final sourceValue = _deepCopy(_read(document, from));
  return _add(document, operation.path, sourceValue);
}

void _test(Map<String, dynamic> document, JsonPatchOperation operation) {
  final current = _read(document, operation.path);
  if (!_deepEquals(current, operation.value)) {
    throw FormatException('Test failed at path "${operation.path}".');
  }
}

dynamic _read(Map<String, dynamic> document, String path) {
  final segments = parsePath(path);
  if (segments.isEmpty) {
    return document;
  }

  dynamic current = document;
  for (final segment in segments) {
    if (current is Map<String, dynamic>) {
      if (!current.containsKey(segment)) {
        throw FormatException('Path "$path" does not exist.');
      }
      current = current[segment];
      continue;
    }

    if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) {
        throw FormatException('Invalid index "$segment" in path "$path".');
      }
      current = current[index];
      continue;
    }

    throw FormatException('Cannot read path "$path".');
  }

  return current;
}

dynamic _traverse(Map<String, dynamic> document, List<String> parentSegments) {
  dynamic current = document;

  for (final segment in parentSegments) {
    if (current is Map<String, dynamic>) {
      if (!current.containsKey(segment)) {
        throw FormatException('Path segment "$segment" does not exist.');
      }
      current = current[segment];
      continue;
    }

    if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) {
        throw FormatException(
          'Invalid index "$segment" while traversing path.',
        );
      }
      current = current[index];
      continue;
    }

    throw FormatException('Cannot traverse into "$segment".');
  }

  return current;
}

JsonPatchOp? _parsePatchOp(String op) {
  switch (op) {
    case 'add':
      return JsonPatchOp.add;
    case 'remove':
      return JsonPatchOp.remove;
    case 'replace':
      return JsonPatchOp.replace;
    case 'move':
      return JsonPatchOp.move;
    case 'copy':
      return JsonPatchOp.copy;
    case 'test':
      return JsonPatchOp.test;
    default:
      return null;
  }
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  final mapped = <String, dynamic>{};
  source.forEach((key, dynamic value) {
    mapped[key] = _deepCopy(value);
  });
  return mapped;
}

dynamic _deepCopy(dynamic value) {
  if (value is Map) {
    final mapped = <String, dynamic>{};
    value.forEach((key, dynamic nested) {
      mapped[key.toString()] = _deepCopy(nested);
    });
    return mapped;
  }

  if (value is List) {
    return value.map(_deepCopy).toList(growable: true);
  }

  return value;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  return a == b;
}
