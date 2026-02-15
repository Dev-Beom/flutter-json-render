import 'dart:convert';

import 'json_patch.dart';
import 'spec.dart';

/// Result returned from [JsonSpecStreamCompiler.push].
class JsonSpecStreamPushResult {
  const JsonSpecStreamPushResult({
    required this.result,
    required this.newPatches,
  });

  /// Latest compiled spec after processing the pushed chunk.
  final JsonRenderSpec? result;

  /// Patch operations that were accepted from this chunk.
  final List<JsonPatchOperation> newPatches;
}

/// Incrementally compiles streamed chunks into a [JsonRenderSpec].
///
/// Supported line formats (JSONL):
/// - Full spec object: `{ "root": "...", "elements": { ... } }`
/// - Patch op object: `{ "op": "replace", "path": "/root", "value": "..." }`
/// - Patch op array: `[{"op":"add",...}, ...]`
/// - Wrapped patch array: `{ "patch": [ ... ] }`
class JsonSpecStreamCompiler {
  JsonSpecStreamCompiler({JsonRenderSpec? initialSpec})
    : _document = initialSpec?.toJson();

  final List<JsonPatchOperation> _patches = <JsonPatchOperation>[];

  String _buffer = '';
  Map<String, dynamic>? _document;

  JsonRenderSpec? getResult() {
    final document = _document;
    if (document == null) {
      return null;
    }
    return JsonRenderSpec.fromJson(_deepCopyMap(document));
  }

  List<JsonPatchOperation> getPatches() => List.unmodifiable(_patches);

  void reset({JsonRenderSpec? initialSpec}) {
    _buffer = '';
    _patches.clear();
    _document = initialSpec?.toJson();
  }

  JsonSpecStreamPushResult push(String chunk) {
    _buffer += chunk;

    final newPatches = <JsonPatchOperation>[];
    final lines = _buffer.split('\n');

    if (_buffer.endsWith('\n')) {
      _buffer = '';
    } else {
      _buffer = lines.removeLast();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(line);
      final extracted = _extractPatchOps(decoded);
      if (extracted != null) {
        _applyPatchOps(extracted);
        newPatches.addAll(extracted);
        continue;
      }

      if (decoded is Map<String, dynamic> && _looksLikeSpec(decoded)) {
        _document = _deepCopyMap(decoded);
        continue;
      }

      throw FormatException('Unsupported stream line: $line');
    }

    _patches.addAll(newPatches);

    return JsonSpecStreamPushResult(
      result: getResult(),
      newPatches: List.unmodifiable(newPatches),
    );
  }

  bool _looksLikeSpec(Map<String, dynamic> decoded) {
    return decoded.containsKey('root') && decoded.containsKey('elements');
  }

  List<JsonPatchOperation>? _extractPatchOps(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .map(
            (entry) => JsonPatchOperation.fromJson(_asStringDynamicMap(entry)),
          )
          .toList(growable: false);
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('op') && decoded.containsKey('path')) {
        return <JsonPatchOperation>[JsonPatchOperation.fromJson(decoded)];
      }

      if (decoded['patch'] is List) {
        final patchList = decoded['patch'] as List;
        return patchList
            .map(
              (entry) =>
                  JsonPatchOperation.fromJson(_asStringDynamicMap(entry)),
            )
            .toList(growable: false);
      }
    }

    return null;
  }

  void _applyPatchOps(List<JsonPatchOperation> operations) {
    _document ??= <String, dynamic>{};

    _document = applyJsonPatch(_document!, operations);
  }
}

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is! Map) {
    throw const FormatException('Patch entry must be a JSON object.');
  }

  final mapped = <String, dynamic>{};
  value.forEach((key, dynamic v) {
    mapped[key.toString()] = v;
  });
  return mapped;
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
    return value.map(_deepCopy).toList(growable: false);
  }

  return value;
}
