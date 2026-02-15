import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('JsonRenderSpec parses flat JSON format', () {
    final spec = JsonRenderSpec.fromJson({
      'root': 'root',
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
}
