import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('JsonRenderSpec parses flat JSON format', () {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
      'style': 'clean',
      'state': {'count': 1},
      'elements': {
        'root': {
          'type': 'Column',
          'children': ['title'],
        },
        'title': {
          'type': 'Text',
          'props': {'text': 'Hello'},
        },
      },
    });

    expect(spec.root, 'root');
    expect(spec.style, 'clean');
    expect(spec.state['count'], 1);
    expect(spec.elements['title']?.type, 'Text');
  });

  test('validateSpec reports missing child references', () {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
      'elements': {
        'root': {
          'type': 'Column',
          'children': ['missing-child'],
        },
      },
    });

    final result = validateSpec(spec);
    expect(result.isValid, isFalse);
    expect(
      result.issues.any((issue) => issue.message.contains('missing child')),
      isTrue,
    );
  });

  test('validateSpec reports unknown style when catalog is provided', () {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
      'style': 'missing-style',
      'elements': {
        'root': {'type': 'Column', 'children': []},
      },
    });

    final result = validateSpec(
      spec,
      catalog: const JsonCatalog(
        components: {'Column': JsonComponentDefinition()},
        styles: {'clean': JsonStyleDefinition()},
      ),
      strictCatalog: false,
    );

    expect(
      result.issues.any((issue) => issue.message.contains('unknown style')),
      isTrue,
    );
  });

  testWidgets(
    'JsonRenderer renders, repeats, resolves state, and handles actions',
    (tester) async {
      final spec = JsonRenderSpec.fromJson({
        'root': 'root',
        'state': {
          'count': 1,
          'show': false,
          'items': [
            {'name': 'Alice'},
            {'name': 'Bob'},
          ],
        },
        'elements': {
          'root': {
            'type': 'Column',
            'props': {'spacing': 8},
            'children': ['title', 'count', 'repeater', 'conditional', 'button'],
          },
          'title': {
            'type': 'Text',
            'props': {'text': 'Hello'},
          },
          'count': {
            'type': 'Text',
            'props': {
              'text': {r'$state': '/count'},
            },
          },
          'repeater': {
            'type': 'Column',
            'repeat': {'statePath': '/items'},
            'children': ['itemText'],
          },
          'itemText': {
            'type': 'Text',
            'props': {
              'text': {r'$item': 'name'},
            },
          },
          'conditional': {
            'type': 'Text',
            'visible': {r'$state': '/show', 'eq': true},
            'props': {'text': 'Now Visible'},
          },
          'button': {
            'type': 'Button',
            'props': {'label': 'Increment'},
            'on': {
              'press': {
                'action': 'increment',
                'params': {
                  'current': {r'$state': '/count'},
                },
              },
            },
          },
        },
      });

      dynamic receivedActionParam;

      final registry = defineRegistry(
        components: standardComponentBuilders(),
        actions: {
          'increment': (ctx) {
            receivedActionParam = ctx.params?['current'];
            ctx.setStateModel((prev) {
              final next = <String, dynamic>{...prev};
              next['count'] = ((next['count'] as num?) ?? 0) + 1;
              next['show'] = true;
              return next;
            });
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonRenderer(spec: spec, registry: registry),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Now Visible'), findsNothing);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(receivedActionParam, 1);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Now Visible'), findsOneWidget);
    },
  );

  testWidgets('Row component supports wrap overflow strategy', (tester) async {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
      'elements': {
        'root': {
          'type': 'Row',
          'props': {'spacing': 8, 'runSpacing': 8, 'overflow': 'wrap'},
          'children': ['a', 'b', 'c'],
        },
        'a': {
          'type': 'Button',
          'props': {'label': 'Very long button A'},
        },
        'b': {
          'type': 'Button',
          'props': {'label': 'Very long button B'},
        },
        'c': {
          'type': 'Button',
          'props': {'label': 'Very long button C'},
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: JsonRenderer(
              spec: spec,
              registry: defineRegistry(components: standardComponentBuilders()),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Wrap), findsOneWidget);
    expect(find.text('Very long button A'), findsOneWidget);
    expect(find.text('Very long button B'), findsOneWidget);
    expect(find.text('Very long button C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('JsonRenderer forwards styleId to component context', (
    tester,
  ) async {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
      'elements': {
        'root': {'type': 'StyleEcho'},
      },
    });

    final registry = defineRegistry(
      components: {'StyleEcho': (ctx) => Text(ctx.styleId ?? 'none')},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JsonRenderer(
            spec: spec,
            registry: registry,
            styleId: 'midnight',
          ),
        ),
      ),
    );

    expect(find.text('midnight'), findsOneWidget);
  });
}
