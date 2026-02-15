import 'dart:convert';

/// A flat render specification where elements are keyed by ID.
class JsonRenderSpec {
  const JsonRenderSpec({
    required this.root,
    required this.elements,
    this.state = const <String, dynamic>{},
  });

  final String root;
  final Map<String, JsonElement> elements;
  final Map<String, dynamic> state;

  factory JsonRenderSpec.fromJson(Map<String, dynamic> json) {
    final rawElements = json['elements'];
    if (rawElements is! Map<String, dynamic>) {
      throw const FormatException('`elements` must be a JSON object.');
    }

    return JsonRenderSpec(
      root: json['root']?.toString() ?? '',
      elements: rawElements.map(
        (key, value) => MapEntry(
          key,
          JsonElement.fromJson(_asMap(value, context: 'elements.$key')),
        ),
      ),
      state: _toStringDynamicMap(json['state']),
    );
  }

  factory JsonRenderSpec.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Spec must decode to a JSON object.');
    }
    return JsonRenderSpec.fromJson(decoded);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'root': root,
      'elements': elements.map((key, value) => MapEntry(key, value.toJson())),
      if (state.isNotEmpty) 'state': state,
    };
  }
}

class JsonElement {
  const JsonElement({
    required this.type,
    this.props = const <String, dynamic>{},
    this.children = const <String>[],
    this.visible,
    this.on = const <String, List<JsonActionBinding>>{},
    this.repeat,
  });

  final String type;
  final Map<String, dynamic> props;
  final List<String> children;

  /// `bool | condition-map | condition-list`
  final dynamic visible;

  /// Event bindings (`eventName -> bindings`)
  final Map<String, List<JsonActionBinding>> on;
  final JsonRepeat? repeat;

  factory JsonElement.fromJson(Map<String, dynamic> json) {
    return JsonElement(
      type: json['type']?.toString() ?? '',
      props: _toStringDynamicMap(json['props']),
      children: _toStringList(json['children']),
      visible: json['visible'],
      on: _parseOn(json['on']),
      repeat: json['repeat'] == null
          ? null
          : JsonRepeat.fromJson(_asMap(json['repeat'], context: 'repeat')),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      if (props.isNotEmpty) 'props': props,
      if (children.isNotEmpty) 'children': children,
      if (visible != null) 'visible': visible,
      if (on.isNotEmpty)
        'on': on.map((event, bindings) {
          if (bindings.length == 1) {
            return MapEntry(event, bindings.first.toJson());
          }
          return MapEntry(
            event,
            bindings.map((entry) => entry.toJson()).toList(),
          );
        }),
      if (repeat != null) 'repeat': repeat!.toJson(),
    };
  }

  static Map<String, List<JsonActionBinding>> _parseOn(dynamic value) {
    if (value == null) return const <String, List<JsonActionBinding>>{};
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        '`on` must be an object mapping event names.',
      );
    }

    final parsed = <String, List<JsonActionBinding>>{};
    value.forEach((event, bindingValue) {
      if (bindingValue is List) {
        parsed[event] = bindingValue
            .map(
              (entry) => JsonActionBinding.fromJson(
                _asMap(entry, context: 'on.$event[]'),
              ),
            )
            .toList(growable: false);
      } else {
        parsed[event] = <JsonActionBinding>[
          JsonActionBinding.fromJson(
            _asMap(bindingValue, context: 'on.$event'),
          ),
        ];
      }
    });

    return parsed;
  }
}

class JsonRepeat {
  const JsonRepeat({required this.statePath, this.key});

  final String statePath;
  final String? key;

  factory JsonRepeat.fromJson(Map<String, dynamic> json) {
    return JsonRepeat(
      statePath: json['statePath']?.toString() ?? '',
      key: json['key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'statePath': statePath,
      if (key != null) 'key': key,
    };
  }
}

class JsonActionBinding {
  const JsonActionBinding({required this.action, this.params});

  final String action;
  final Map<String, dynamic>? params;

  factory JsonActionBinding.fromJson(Map<String, dynamic> json) {
    return JsonActionBinding(
      action: json['action']?.toString() ?? '',
      params: _toStringDynamicMap(json['params']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'action': action,
      if (params != null && params!.isNotEmpty) 'params': params,
    };
  }
}

Map<String, dynamic> _asMap(dynamic value, {required String context}) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('`$context` must be a JSON object.');
}

Map<String, dynamic> _toStringDynamicMap(dynamic value) {
  if (value == null) return const <String, dynamic>{};
  if (value is! Map) {
    throw const FormatException('Expected a JSON object.');
  }

  final mapped = <String, dynamic>{};
  value.forEach((key, dynamic raw) {
    mapped[key.toString()] = raw;
  });
  return mapped;
}

List<String> _toStringList(dynamic value) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throw const FormatException('Expected a JSON array.');
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}
