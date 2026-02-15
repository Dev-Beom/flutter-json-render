# flutter_json_render

A Flutter-first implementation of the [vercel-labs/json-render](https://github.com/vercel-labs/json-render) concept.

`flutter_json_render` renders flat JSON specs into Flutter widgets through an explicit registry and catalog.

- Guardrailed component/action model
- Flat and model-friendly spec shape (`root + elements`)
- Dynamic prop resolution (`$state`, `$item`, `$index`, `$cond`)
- Visibility and repeat support
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
        child: JsonRenderer(spec: spec, registry: registry),
      ),
    ),
  );
}
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

## pub.dev Release Checklist

```bash
flutter analyze
flutter test
dart pub publish --dry-run
```

## License

MIT
