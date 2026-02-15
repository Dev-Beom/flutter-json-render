import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

void main() {
  test('applyJsonPatch supports add/replace/remove', () {
    final document = <String, dynamic>{
      'root': 'a',
      'elements': <String, dynamic>{
        'a': <String, dynamic>{'type': 'Text', 'props': <String, dynamic>{}},
      },
    };

    final patched = applyJsonPatch(document, <JsonPatchOperation>[
      const JsonPatchOperation(
        op: JsonPatchOp.add,
        path: '/elements/a/props/text',
        value: 'hello',
      ),
      const JsonPatchOperation(
        op: JsonPatchOp.replace,
        path: '/root',
        value: 'b',
      ),
      const JsonPatchOperation(
        op: JsonPatchOp.add,
        path: '/elements/b',
        value: <String, dynamic>{'type': 'Column', 'children': <String>[]},
      ),
      const JsonPatchOperation(op: JsonPatchOp.remove, path: '/elements/a'),
    ]);

    expect(patched['root'], 'b');
    expect((patched['elements'] as Map<String, dynamic>)['a'], isNull);
    expect((patched['elements'] as Map<String, dynamic>)['b'], isNotNull);
  });

  test('applyJsonPatch supports list add and move/copy/test', () {
    final document = <String, dynamic>{
      'items': <dynamic>['a', 'b'],
      'result': <dynamic>[],
    };

    final patched = applyJsonPatch(document, <JsonPatchOperation>[
      const JsonPatchOperation(
        op: JsonPatchOp.add,
        path: '/items/2',
        value: 'c',
      ),
      const JsonPatchOperation(
        op: JsonPatchOp.copy,
        from: '/items/0',
        path: '/result/0',
      ),
      const JsonPatchOperation(
        op: JsonPatchOp.move,
        from: '/items/1',
        path: '/result/1',
      ),
      const JsonPatchOperation(
        op: JsonPatchOp.test,
        path: '/result/0',
        value: 'a',
      ),
    ]);

    expect(patched['items'], <dynamic>['a', 'c']);
    expect(patched['result'], <dynamic>['a', 'b']);
  });
}
