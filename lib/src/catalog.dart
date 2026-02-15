import 'spec.dart';

typedef JsonPropsValidator = void Function(Map<String, dynamic> props);

class JsonPropDefinition {
  const JsonPropDefinition({
    required this.type,
    this.description = '',
    this.required = false,
    this.enumValues = const <String>[],
    this.example,
    this.defaultValue,
  });

  final String type;
  final String description;
  final bool required;
  final List<String> enumValues;
  final dynamic example;
  final dynamic defaultValue;
}

class JsonComponentDefinition {
  const JsonComponentDefinition({
    this.description = '',
    this.props = const <String, JsonPropDefinition>{},
    this.examples = const <Map<String, dynamic>>[],
    this.validateProps,
  });

  final String description;
  final Map<String, JsonPropDefinition> props;
  final List<Map<String, dynamic>> examples;
  final JsonPropsValidator? validateProps;
}

class JsonActionDefinition {
  const JsonActionDefinition({
    this.description = '',
    this.params = const <String, JsonPropDefinition>{},
  });

  final String description;
  final Map<String, JsonPropDefinition> params;
}

class JsonStyleDefinition {
  const JsonStyleDefinition({
    this.displayName = '',
    this.description = '',
    this.guidance = '',
    this.tokens = const <String, dynamic>{},
  });

  factory JsonStyleDefinition.fromJson(Map<String, dynamic> json) {
    return JsonStyleDefinition(
      displayName: json['displayName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      guidance: json['guidance']?.toString() ?? '',
      tokens: _normalizeJsonMap(json['tokens']),
    );
  }

  final String displayName;
  final String description;
  final String guidance;
  final Map<String, dynamic> tokens;

  JsonStyleDefinition copyWith({
    String? displayName,
    String? description,
    String? guidance,
    Map<String, dynamic>? tokens,
  }) {
    return JsonStyleDefinition(
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      guidance: guidance ?? this.guidance,
      tokens: tokens ?? this.tokens,
    );
  }

  JsonStyleDefinition merge(JsonStyleDefinition overlay) {
    return JsonStyleDefinition(
      displayName: overlay.displayName.trim().isEmpty
          ? displayName
          : overlay.displayName,
      description: overlay.description.trim().isEmpty
          ? description
          : overlay.description,
      guidance: overlay.guidance.trim().isEmpty ? guidance : overlay.guidance,
      tokens: <String, dynamic>{...tokens, ...overlay.tokens},
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    final displayName = this.displayName.trim();
    final description = this.description.trim();
    final guidance = this.guidance.trim();
    if (displayName.isNotEmpty) {
      map['displayName'] = displayName;
    }
    if (description.isNotEmpty) {
      map['description'] = description;
    }
    if (guidance.isNotEmpty) {
      map['guidance'] = guidance;
    }
    if (tokens.isNotEmpty) {
      map['tokens'] = _copyJsonValue(tokens) as Map<String, dynamic>;
    }
    return map;
  }
}

class JsonPromptOptions {
  const JsonPromptOptions({
    this.includeProps = true,
    this.includeExamples = true,
    this.includeActions = true,
    this.includeStyles = true,
    this.selectedStyleId,
  });

  final bool includeProps;
  final bool includeExamples;
  final bool includeActions;
  final bool includeStyles;
  final String? selectedStyleId;
}

class JsonCatalog {
  const JsonCatalog({
    this.components = const <String, JsonComponentDefinition>{},
    this.actions = const <String, JsonActionDefinition>{},
    this.styles = const <String, JsonStyleDefinition>{},
  });

  final Map<String, JsonComponentDefinition> components;
  final Map<String, JsonActionDefinition> actions;
  final Map<String, JsonStyleDefinition> styles;

  bool hasComponent(String type) => components.containsKey(type);

  bool hasAction(String action) => actions.containsKey(action);

  bool hasStyle(String styleId) => styles.containsKey(styleId);

  JsonCatalog withStyle(String styleId, JsonStyleDefinition style) {
    return JsonCatalog(
      components: components,
      actions: actions,
      styles: <String, JsonStyleDefinition>{...styles, styleId: style},
    );
  }

  JsonCatalog withStyles(Map<String, JsonStyleDefinition> additionalStyles) {
    if (additionalStyles.isEmpty) {
      return this;
    }
    return JsonCatalog(
      components: components,
      actions: actions,
      styles: <String, JsonStyleDefinition>{...styles, ...additionalStyles},
    );
  }

  JsonCatalog withStylesFromJson(Map<String, dynamic> rawStyles) {
    if (rawStyles.isEmpty) {
      return this;
    }
    final parsed = <String, JsonStyleDefinition>{};
    for (final entry in rawStyles.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value;
      if (value is JsonStyleDefinition) {
        parsed[key] = value;
      } else if (value is Map<String, dynamic>) {
        parsed[key] = JsonStyleDefinition.fromJson(value);
      } else if (value is Map) {
        parsed[key] = JsonStyleDefinition.fromJson(
          Map<String, dynamic>.from(value),
        );
      } else {
        throw FormatException(
          'Style "$key" must be a JsonStyleDefinition or JSON object.',
        );
      }
    }
    return withStyles(parsed);
  }

  /// Builds an LLM-friendly system prompt from this catalog.
  String prompt({JsonPromptOptions options = const JsonPromptOptions()}) {
    final buffer = StringBuffer()
      ..writeln('You can only generate UI using this catalog.')
      ..writeln('Output must be valid JSON in flat format:')
      ..writeln('{ "root": "...", "elements": { ... }, "state": { ... } }')
      ..writeln('Each element must include "type" and may include "props",')
      ..writeln('"children", "visible", "repeat", and "on".')
      ..writeln('');

    buffer.writeln('Components:');
    if (components.isEmpty) {
      buffer.writeln('- none');
    } else {
      for (final entry in components.entries) {
        final name = entry.key;
        final definition = entry.value;
        final description = definition.description.trim();

        if (description.isEmpty) {
          buffer.writeln('- $name');
        } else {
          buffer.writeln('- $name: $description');
        }

        if (options.includeProps && definition.props.isNotEmpty) {
          buffer.writeln('  props:');
          for (final propEntry in definition.props.entries) {
            buffer.writeln(
              '  - ${_renderProp(name: propEntry.key, def: propEntry.value)}',
            );
          }
        }

        if (options.includeExamples && definition.examples.isNotEmpty) {
          buffer.writeln('  examples:');
          for (final example in definition.examples) {
            buffer.writeln('  - $example');
          }
        }
      }
    }

    if (options.includeStyles) {
      buffer.writeln('');
      buffer.writeln('Styles:');
      if (styles.isEmpty) {
        buffer.writeln('- none');
      } else {
        final selectedStyleId = options.selectedStyleId;
        if (selectedStyleId != null) {
          if (hasStyle(selectedStyleId)) {
            final selected = styles[selectedStyleId]!;
            final displayName = selected.displayName.trim().isEmpty
                ? selectedStyleId
                : selected.displayName.trim();
            buffer.writeln('Selected style: $selectedStyleId ($displayName)');
          } else {
            buffer.writeln('Selected style: $selectedStyleId (unknown)');
          }
        }

        for (final entry in styles.entries) {
          final styleId = entry.key;
          final style = entry.value;
          final displayName = style.displayName.trim();
          final description = style.description.trim();
          final guidance = style.guidance.trim();

          if (displayName.isEmpty) {
            buffer.writeln('- $styleId');
          } else {
            buffer.writeln('- $styleId ($displayName)');
          }

          if (description.isNotEmpty) {
            buffer.writeln('  description: $description');
          }
          if (guidance.isNotEmpty) {
            buffer.writeln('  guidance: $guidance');
          }
          if (style.tokens.isNotEmpty) {
            buffer.writeln('  tokens: ${style.tokens}');
          }
        }
      }
    }

    if (options.includeActions) {
      buffer.writeln('');
      buffer.writeln('Actions:');
      if (actions.isEmpty) {
        buffer.writeln('- none');
      } else {
        for (final entry in actions.entries) {
          final name = entry.key;
          final definition = entry.value;
          final description = definition.description.trim();

          if (description.isEmpty) {
            buffer.writeln('- $name');
          } else {
            buffer.writeln('- $name: $description');
          }

          if (definition.params.isNotEmpty) {
            buffer.writeln('  params:');
            for (final param in definition.params.entries) {
              buffer.writeln(
                '  - ${_renderProp(name: param.key, def: param.value)}',
              );
            }
          }
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('Rules:');
    buffer.writeln('- Use only listed component types and actions.');
    if (options.selectedStyleId != null) {
      buffer.writeln(
        '- Apply selected style "${options.selectedStyleId}" consistently.',
      );
    }
    buffer.writeln('- Keep children references valid and acyclic.');
    buffer.writeln('- Prefer concise props; avoid unknown keys.');

    return buffer.toString().trimRight();
  }

  void validateElementProps(JsonRenderSpec spec) {
    for (final entry in spec.elements.entries) {
      final definition = components[entry.value.type];
      final validator = definition?.validateProps;
      if (validator == null) {
        continue;
      }
      validator(entry.value.props);
    }
  }
}

String _renderProp({required String name, required JsonPropDefinition def}) {
  final buffer = StringBuffer()
    ..write(name)
    ..write(' (')
    ..write(def.type)
    ..write(def.required ? ', required' : ', optional')
    ..write(')');

  if (def.enumValues.isNotEmpty) {
    buffer.write(', enum: [${def.enumValues.join(', ')}]');
  }

  final description = def.description.trim();
  if (description.isNotEmpty) {
    buffer.write(' - $description');
  }

  if (def.defaultValue != null) {
    buffer.write(' (default: ${def.defaultValue})');
  }

  if (def.example != null) {
    buffer.write(' (example: ${def.example})');
  }

  return buffer.toString();
}

Map<String, dynamic> _normalizeJsonMap(dynamic raw) {
  if (raw is! Map) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.from(_copyJsonValue(raw) as Map);
}

dynamic _copyJsonValue(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = _copyJsonValue(entry.value);
    }
    return out;
  }
  if (value is List) {
    return value.map(_copyJsonValue).toList(growable: false);
  }
  return value;
}
