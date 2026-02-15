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

class JsonPromptOptions {
  const JsonPromptOptions({
    this.includeProps = true,
    this.includeExamples = true,
    this.includeActions = true,
  });

  final bool includeProps;
  final bool includeExamples;
  final bool includeActions;
}

class JsonCatalog {
  const JsonCatalog({
    this.components = const <String, JsonComponentDefinition>{},
    this.actions = const <String, JsonActionDefinition>{},
  });

  final Map<String, JsonComponentDefinition> components;
  final Map<String, JsonActionDefinition> actions;

  bool hasComponent(String type) => components.containsKey(type);

  bool hasAction(String action) => actions.containsKey(action);

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
