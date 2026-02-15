# flutter_json_render

A Flutter-first implementation of the [vercel-labs/json-render](https://github.com/vercel-labs/json-render) concept.

`flutter_json_render` renders flat JSON specs into Flutter widgets through an explicit registry and catalog.

- Guardrailed component/action model
- Flat and model-friendly spec shape (`root + elements`)
- Dynamic prop resolution (`$state`, `$item`, `$index`, `$cond`)
- Visibility and repeat support
- Style presets and style-aware prompt generation
- JSONL streaming patch compiler for progressive UI updates

## Install

```bash
flutter pub add flutter_json_render
```

## Core Concepts

- `JsonCatalog`: declares what components/actions are allowed
- `JsonRegistry`: maps component type -> Flutter widget builder, action -> handler
- `JsonRenderer`: renders `JsonRenderSpec` safely
- `JsonSpecStreamCompiler`: compiles streamed JSONL specs/patches
- `JsonStyleDefinition`: defines selectable style presets for generation/runtime

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

final catalog = JsonCatalog(
  components: {
    ...standardComponentDefinitions,
    'Panel': const JsonComponentDefinition(
      description: 'Simple card container',
      props: {
        'title': JsonPropDefinition(type: 'string', required: true),
      },
    ),
  },
  actions: {
    ...standardActionDefinitions,
    'increment': const JsonActionDefinition(description: 'Increase count'),
  },
  styles: {
    'clean': const JsonStyleDefinition(
      displayName: 'Clean',
      description: 'Neutral and productivity-focused',
      guidance: 'Use subtle borders and restrained color.',
    ),
    'midnight': const JsonStyleDefinition(
      displayName: 'Midnight',
      description: 'Dark, high-contrast dashboard style',
      guidance: 'Use compact spacing and bright accents.',
    ),
  },
);

final registry = defineRegistry(
  components: {
    ...standardComponentBuilders(),
    'Panel': (ctx) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.props['title']?.toString() ?? 'Panel'),
            const SizedBox(height: 8),
            ...ctx.children,
          ],
        ),
      ),
    ),
  },
  actions: {
    'increment': (ctx) {
      ctx.setStateModel((prev) {
        final next = <String, dynamic>{...prev};
        next['count'] = ((prev['count'] as num?) ?? 0) + 1;
        return next;
      });
    },
  },
);

final spec = JsonRenderSpec.fromJson({
  'root': 'panel',
  'state': {'count': 1},
  'elements': {
    'panel': {
      'type': 'Panel',
      'props': {'title': 'Counter'},
      'children': ['value', 'button'],
    },
    'value': {
      'type': 'Text',
      'props': {'text': {'$state': '/count'}},
    },
    'button': {
      'type': 'Button',
      'props': {'label': 'Increment'},
      'on': {
        'press': {'action': 'increment'}
      }
    }
  }
});

Widget app() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: JsonRenderer(
          spec: spec,
          registry: registry,
          styleId: 'clean', // runtime-selected style
        ),
      ),
    ),
  );
}
```

Generate style-aware LLM prompts:

```dart
final prompt = catalog.prompt(
  options: const JsonPromptOptions(
    selectedStyleId: 'clean',
    includeStyles: true,
  ),
);
```

## Stream JSONL Patches

```dart
final compiler = JsonSpecStreamCompiler();

compiler.push('{"root":"root","elements":{"root":{"type":"Text","props":{"text":"loading"}}}}\n');
compiler.push('{"op":"replace","path":"/elements/root/props/text","value":"ready"}\n');

final spec = compiler.getResult();
```

Supported stream line shapes:

- full spec object
- single patch op object
- patch op array
- wrapped patch object: `{ "patch": [ ... ] }`

## Validate Specs

```dart
final result = validateSpec(spec, catalog: catalog, strictCatalog: false);
if (!result.isValid) {
  for (final issue in result.issues) {
    debugPrint('[${issue.severity}] ${issue.message}');
  }
}
```

## Built-In Components

- `Text`
- `Column`
- `Row`
- `Container`
- `Center`
- `SizedBox`
- `Button`
- `Image`

`Row` overflow strategy:

- `overflow: "row"` (default): normal `Row`
- `overflow: "wrap"`: uses `Wrap` to avoid horizontal overflow
- `overflow: "scroll"`: horizontal scroll container

Example:

```json
{
  "type": "Row",
  "props": {
    "spacing": 8,
    "runSpacing": 8,
    "overflow": "wrap"
  },
  "children": ["a", "b", "c"]
}
```

## Example App

A full multi-scenario showcase app is included in `/example`:

```bash
cd example
flutter run
```

Included scenarios:

- Counter + visibility conditions
- Repeat + `$item`/`$index` actions
- Dynamic props via `$cond`
- Async action flow
- Streamed JSONL patch simulation

The example includes a `Style Preset` dropdown and supports startup style selection:

```bash
cd example
flutter run --dart-define=STYLE_PRESET=midnight
```

### Style Preset Screenshots

| clean | midnight | sunset |
|---|---|---|
| ![clean](https://raw.githubusercontent.com/Dev-Beom/flutter-json-render/main/assets/screenshots/example-style-clean.png) | ![midnight](https://raw.githubusercontent.com/Dev-Beom/flutter-json-render/main/assets/screenshots/example-style-midnight.png) | ![sunset](https://raw.githubusercontent.com/Dev-Beom/flutter-json-render/main/assets/screenshots/example-style-sunset.png) |

## pub.dev Release Checklist

```bash
flutter analyze
flutter test
dart pub publish --dry-run
```

## License

MIT
