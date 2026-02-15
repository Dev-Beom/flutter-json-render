List<String> parsePath(String path) {
  if (path.isEmpty || path == '/') {
    return const <String>[];
  }

  if (path.startsWith('/')) {
    return path
        .split('/')
        .skip(1)
        .where((segment) => segment.isNotEmpty)
        .map(_decodeJsonPointerToken)
        .toList(growable: false);
  }

  return path
      .split('.')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

String _decodeJsonPointerToken(String token) {
  return token.replaceAll('~1', '/').replaceAll('~0', '~');
}

dynamic getByPath(dynamic source, String path) {
  final segments = parsePath(path);
  dynamic current = source;

  for (final segment in segments) {
    if (current == null) return null;

    if (current is Map) {
      current = current[segment];
      continue;
    }

    if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) {
        return null;
      }
      current = current[index];
      continue;
    }

    return null;
  }

  return current;
}

String appendPath(String base, String segment) {
  if (base.isEmpty || base == '/') {
    return '/$segment';
  }
  if (base.endsWith('/')) {
    return '$base$segment';
  }
  return '$base/$segment';
}
