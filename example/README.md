# flutter_json_render example

Showcase app for the package with practical scenarios:

1. Counter + visibility conditions
2. Repeat + `$item`/`$index` actions
3. Dynamic props with `$cond`
4. Async action flow
5. Streamed JSONL patch simulation
6. Style preset switching (`clean`, `midnight`, `sunset`)

Run:

```bash
flutter pub get
flutter run
```

Run with a preset at startup:

```bash
flutter run --dart-define=STYLE_PRESET=midnight
```
