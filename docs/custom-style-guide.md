# Custom Style Guide

This guide explains how to create custom styles for `flutter_json_render`.

## 1) Style Data Model

Use `JsonStyleDefinition` for style metadata and optional token payload.

```dart
const style = JsonStyleDefinition(
  displayName: 'Aurora',
  description: 'Deep blue surface with cyan accents.',
  guidance: 'Use high contrast and cool color highlights.',
  tokens: <String, dynamic>{
    'accent': '#22D3EE',
    'panelBackground': '#0B1220',
    'textPrimary': '#E0F2FE',
  },
);
```

## 2) Create Styles from JSON

```dart
final style = JsonStyleDefinition.fromJson(<String, dynamic>{
  'displayName': 'Aurora',
  'description': 'Deep blue surface with cyan accents.',
  'guidance': 'Use high contrast and cool color highlights.',
  'tokens': <String, dynamic>{
    'accent': '#22D3EE',
    'panelBackground': '#0B1220',
    'textPrimary': '#E0F2FE',
  },
});
```

`tokens` is intentionally open-ended so your renderer can define its own token contract.

## 3) Register Custom Styles

Single style:

```dart
final catalog = baseCatalog.withStyle('aurora', style);
```

Batch style import:

```dart
final catalog = baseCatalog.withStylesFromJson(<String, dynamic>{
  'aurora': <String, dynamic>{
    'displayName': 'Aurora',
    'description': 'Deep blue surface with cyan accents.',
    'guidance': 'Use high contrast and cool color highlights.',
    'tokens': <String, dynamic>{
      'accent': '#22D3EE',
      'panelBackground': '#0B1220',
      'textPrimary': '#E0F2FE',
    },
  },
  'warm': <String, dynamic>{
    'displayName': 'Warm',
    'description': 'Cream cards with orange emphasis.',
    'guidance': 'Use warm neutrals and soft border contrast.',
    'tokens': <String, dynamic>{
      'accent': '#EA580C',
      'panelBackground': '#FFF7ED',
      'textPrimary': '#7C2D12',
    },
  },
});
```

## 4) Prompting with Selected Style

```dart
final systemPrompt = catalog.prompt(
  options: const JsonPromptOptions(
    includeStyles: true,
    selectedStyleId: 'aurora',
  ),
);
```

This makes LLM generation style-aware while still restricting output to your catalog.

## 5) Example App Runtime Injection

The example app supports runtime custom style injection with `CUSTOM_STYLE_JSON`:

```bash
cd example
flutter run \
  --dart-define=STYLE_PRESET=sunset \
  --dart-define=CUSTOM_STYLE_JSON='{"id":"aurora","base":"midnight","displayName":"Aurora","description":"Deep blue surface with bright cyan accents.","guidance":"Use high contrast and cool accent colors.","tokens":{"accent":"#22D3EE","panelBackground":"#0B1220","textPrimary":"#E0F2FE"}}'
```

You can also apply JSON from the in-app `Add Custom Style` dialog.
