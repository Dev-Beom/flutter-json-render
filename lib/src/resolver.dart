import 'json_path.dart';
import 'registry.dart';
import 'visibility.dart';

class JsonResolutionContext {
  const JsonResolutionContext({required this.state, this.repeatScope});

  final Map<String, dynamic> state;
  final JsonRepeatScope? repeatScope;
}

bool isTruthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
  final copy = <String, dynamic>{};
  for (final entry in source.entries) {
    copy[entry.key] = deepCopyValue(entry.value);
  }
  return copy;
}

dynamic deepCopyValue(dynamic value) {
  if (value is Map) {
    final mapped = <String, dynamic>{};
    value.forEach((key, dynamic item) {
      mapped[key.toString()] = deepCopyValue(item);
    });
    return mapped;
  }

  if (value is List) {
    return value.map(deepCopyValue).toList(growable: false);
  }

  return value;
}

dynamic resolveValue(dynamic value, JsonResolutionContext context) {
  if (value is List) {
    return value
        .map((entry) => resolveValue(entry, context))
        .toList(growable: false);
  }

  if (value is! Map) {
    return value;
  }

  if (_looksLikeStateRef(value)) {
    final path = value[r'$state']?.toString() ?? '';
    return getByPath(context.state, path);
  }

  if (_looksLikeItemRef(value)) {
    final itemPath = value[r'$item']?.toString() ?? '';
    final item = context.repeatScope?.item;
    if (itemPath.isEmpty) {
      return item;
    }
    return getByPath(item, itemPath);
  }

  if (_looksLikeIndexRef(value)) {
    return context.repeatScope?.index;
  }

  if (value.containsKey(r'$cond')) {
    final condition = value[r'$cond'];
    final result = evaluateVisibility(condition, context);
    final branch = result ? value[r'$then'] : value[r'$else'];
    return resolveValue(branch, context);
  }

  final mapped = <String, dynamic>{};
  value.forEach((key, dynamic raw) {
    mapped[key.toString()] = resolveValue(raw, context);
  });
  return mapped;
}

Map<String, dynamic> resolveProps(
  Map<String, dynamic> props,
  JsonResolutionContext context,
) {
  final resolved = <String, dynamic>{};
  props.forEach((key, dynamic value) {
    resolved[key] = resolveValue(value, context);
  });
  return resolved;
}

bool _looksLikeStateRef(Map<dynamic, dynamic> value) {
  return value.length == 1 && value.containsKey(r'$state');
}

bool _looksLikeItemRef(Map<dynamic, dynamic> value) {
  return value.length == 1 && value.containsKey(r'$item');
}

bool _looksLikeIndexRef(Map<dynamic, dynamic> value) {
  return value.length == 1 && value.containsKey(r'$index');
}
