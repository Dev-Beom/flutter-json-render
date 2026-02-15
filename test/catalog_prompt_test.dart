import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('catalog prompt includes prop metadata and action params', () {
    final catalog = JsonCatalog(
      components: <String, JsonComponentDefinition>{
        'Card': const JsonComponentDefinition(
          description: 'Container card',
          props: <String, JsonPropDefinition>{
            'title': JsonPropDefinition(
              type: 'string',
              required: true,
              description: 'Card title',
            ),
            'variant': JsonPropDefinition(
              type: 'string',
              enumValues: <String>['info', 'warning'],
            ),
          },
          examples: <Map<String, dynamic>>[
            <String, dynamic>{'title': 'Revenue'},
          ],
        ),
      },
      actions: <String, JsonActionDefinition>{
        'refresh': const JsonActionDefinition(
          description: 'Reload metrics',
          params: <String, JsonPropDefinition>{
            'source': JsonPropDefinition(type: 'string'),
          },
        ),
      },
    );

    final prompt = catalog.prompt();

    expect(prompt, contains('Card: Container card'));
    expect(prompt, contains('title (string, required)'));
    expect(
      prompt,
      contains('variant (string, optional), enum: [info, warning]'),
    );
    expect(prompt, contains('refresh: Reload metrics'));
    expect(prompt, contains('source (string, optional)'));
    expect(prompt, contains('Rules:'));
  });

  test('prompt options can exclude sections', () {
    final catalog = JsonCatalog(
      components: <String, JsonComponentDefinition>{
        'Text': const JsonComponentDefinition(
          description: 'simple text',
          props: <String, JsonPropDefinition>{
            'text': JsonPropDefinition(type: 'string', required: true),
          },
        ),
      },
      actions: <String, JsonActionDefinition>{
        'noop': const JsonActionDefinition(description: 'No op'),
      },
    );

    final prompt = catalog.prompt(
      options: const JsonPromptOptions(
        includeProps: false,
        includeActions: false,
      ),
    );

    expect(prompt, contains('Components:'));
    expect(prompt, isNot(contains('params:')));
    expect(prompt, isNot(contains('Actions:')));
  });
}
