import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('JsonStyleDefinition fromJson/toJson roundtrip keeps tokens', () {
    final style = JsonStyleDefinition.fromJson(<String, dynamic>{
      'displayName': 'Aurora',
      'description': 'Cool blue-focused palette',
      'guidance': 'Use cyan accents and calm backgrounds.',
      'tokens': <String, dynamic>{
        'accent': '#22D3EE',
        'panelBackground': '#082F49',
        'neutralChip': <String, dynamic>{
          'background': '#0F172A',
          'border': '#1E293B',
          'foreground': '#E2E8F0',
        },
      },
    });

    expect(style.displayName, 'Aurora');
    expect(style.tokens['accent'], '#22D3EE');
    expect(
      (style.tokens['neutralChip'] as Map<String, dynamic>)['border'],
      '#1E293B',
    );

    final json = style.toJson();
    expect(json['displayName'], 'Aurora');
    expect(
      (json['tokens'] as Map<String, dynamic>)['panelBackground'],
      '#082F49',
    );
  });

  test('JsonStyleDefinition merge applies overlay text and tokens', () {
    const base = JsonStyleDefinition(
      displayName: 'Base',
      description: 'Base style',
      guidance: 'Use balanced spacing.',
      tokens: <String, dynamic>{
        'accent': '#0EA5E9',
        'panelBackground': '#FFFFFF',
      },
    );
    const overlay = JsonStyleDefinition(
      displayName: 'Custom',
      tokens: <String, dynamic>{'accent': '#22D3EE'},
    );

    final merged = base.merge(overlay);

    expect(merged.displayName, 'Custom');
    expect(merged.description, 'Base style');
    expect(merged.tokens['accent'], '#22D3EE');
    expect(merged.tokens['panelBackground'], '#FFFFFF');
  });

  test('JsonCatalog withStylesFromJson parses and upserts styles', () {
    final catalog =
        const JsonCatalog(
          styles: <String, JsonStyleDefinition>{
            'clean': JsonStyleDefinition(displayName: 'Clean'),
          },
        ).withStylesFromJson(<String, dynamic>{
          'aurora': <String, dynamic>{
            'displayName': 'Aurora',
            'description': 'Night mode with cyan accents',
            'tokens': <String, dynamic>{'accent': '#22D3EE'},
          },
        });

    expect(catalog.hasStyle('clean'), isTrue);
    expect(catalog.hasStyle('aurora'), isTrue);
    expect(catalog.styles['aurora']!.displayName, 'Aurora');
    expect(catalog.styles['aurora']!.tokens['accent'], '#22D3EE');
  });
}
