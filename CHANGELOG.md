## 0.3.0

- Added style preset model with `JsonStyleDefinition` and `JsonCatalog.styles`
- Added style-aware prompt generation via `JsonPromptOptions.selectedStyleId`
- Added optional spec-level style (`JsonRenderSpec.style`) and style validation in `validateSpec`
- Added runtime style override support in `JsonRenderer(styleId: ...)`
- Extended render/action contexts with `styleId`
- Improved `Row` overflow handling with `overflow: row|wrap|scroll` and `runSpacing`
- Expanded showcase example with style preset selector (`clean`, `midnight`, `sunset`)
- Added style screenshots and updated README/pub.dev documentation

## 0.2.0

- Added JSON Patch support with `JsonPatchOperation`, `JsonPatchOp`, and `applyJsonPatch`
- Added streaming compiler API `JsonSpecStreamCompiler` for JSONL full specs and incremental patch lines
- Expanded `JsonCatalog.prompt()` with richer schema metadata (`JsonPropDefinition`, `JsonPromptOptions`)
- Enhanced standard component catalog definitions with prop schemas for stronger prompt generation
- Added a full multi-case `/example` app (counter, repeat/item scope, dynamic cond props, async actions, stream simulation)
- Expanded test coverage for patching, streaming, and prompt generation
- Updated README with streaming and example usage docs
- Updated package metadata for publishing readiness

## 0.1.0

- Initial Flutter/Dart library implementation inspired by `vercel-labs/json-render`
- Added flat spec model (`JsonRenderSpec`, `JsonElement`, actions/repeat support)
- Added guarded catalog and registry APIs (`JsonCatalog`, `JsonRegistry`)
- Added `JsonRenderer` with visibility, repeat, dynamic value resolution, and event-action dispatch
- Added built-in standard component set for Material widgets
- Added spec validation API (`validateSpec`)
- Added widget and unit tests for rendering, action execution, visibility, and repeat
