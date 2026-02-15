import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('compiler accepts full spec line then patch lines', () {
    final compiler = JsonSpecStreamCompiler();

    final fullSpecLine = jsonEncode(<String, dynamic>{
      'root': 'root',
      'state': <String, dynamic>{'count': 1},
      'elements': <String, dynamic>{
        'root': <String, dynamic>{
          'type': 'Column',
          'children': <String>['count'],
        },
        'count': <String, dynamic>{
          'type': 'Text',
          'props': <String, dynamic>{
            'text': <String, dynamic>{r'$state': '/count'},
          },
        },
      },
    });

    final first = compiler.push('$fullSpecLine\n');
    expect(first.result, isNotNull);
    expect(first.newPatches, isEmpty);

    final second = compiler.push(
      '{"op":"replace","path":"/state/count","value":2}\n',
    );

    expect(second.newPatches.length, 1);
    expect(second.result?.state['count'], 2);
  });

  test('compiler buffers partial lines and applies patch arrays', () {
    final compiler = JsonSpecStreamCompiler(
      initialSpec: JsonRenderSpec.fromJson(<String, dynamic>{
        'root': 'root',
        'elements': <String, dynamic>{
          'root': <String, dynamic>{'type': 'Column', 'children': <String>[]},
        },
      }),
    );

    final chunkA =
        '{"patch":[{"op":"add","path":"/elements/title","value":{"type":"Text"';
    final chunkB =
        ',"props":{"text":"hello"}}},{"op":"add","path":"/elements/root/children","value":["title"]}]}\n';

    final interim = compiler.push(chunkA);
    expect(interim.newPatches, isEmpty);

    final finalResult = compiler.push(chunkB);
    expect(finalResult.newPatches.length, 2);

    final spec = finalResult.result!;
    expect(spec.elements['title']?.type, 'Text');
    expect(spec.elements['root']?.children, <String>['title']);
  });
}
