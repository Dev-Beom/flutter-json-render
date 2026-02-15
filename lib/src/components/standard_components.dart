import 'package:flutter/material.dart';

import '../catalog.dart';
import '../registry.dart';

final Map<String, JsonComponentDefinition> standardComponentDefinitions =
    <String, JsonComponentDefinition>{
      'Text': const JsonComponentDefinition(
        description: 'Displays plain text.',
        props: <String, JsonPropDefinition>{
          'text': JsonPropDefinition(
            type: 'string',
            required: true,
            description: 'Text value or dynamic expression.',
          ),
          'align': JsonPropDefinition(
            type: 'string',
            enumValues: <String>['left', 'center', 'right', 'justify'],
          ),
          'fontSize': JsonPropDefinition(type: 'number'),
          'fontWeight': JsonPropDefinition(type: 'string'),
          'color': JsonPropDefinition(type: 'string'),
        },
      ),
      'Column': const JsonComponentDefinition(
        description: 'Vertical layout for children widgets.',
        props: <String, JsonPropDefinition>{
          'spacing': JsonPropDefinition(type: 'number', defaultValue: 0),
          'mainAxisAlignment': JsonPropDefinition(type: 'string'),
          'crossAxisAlignment': JsonPropDefinition(type: 'string'),
          'mainAxisSize': JsonPropDefinition(
            type: 'string',
            enumValues: <String>['min', 'max'],
          ),
        },
      ),
      'Row': const JsonComponentDefinition(
        description: 'Horizontal layout for children widgets.',
        props: <String, JsonPropDefinition>{
          'spacing': JsonPropDefinition(type: 'number', defaultValue: 0),
          'mainAxisAlignment': JsonPropDefinition(type: 'string'),
          'crossAxisAlignment': JsonPropDefinition(type: 'string'),
          'mainAxisSize': JsonPropDefinition(
            type: 'string',
            enumValues: <String>['min', 'max'],
          ),
        },
      ),
      'Container': const JsonComponentDefinition(
        description: 'Box wrapper with padding, margin, color, and radius.',
        props: <String, JsonPropDefinition>{
          'width': JsonPropDefinition(type: 'number'),
          'height': JsonPropDefinition(type: 'number'),
          'padding': JsonPropDefinition(type: 'number | [l,t,r,b] | object'),
          'margin': JsonPropDefinition(type: 'number | [l,t,r,b] | object'),
          'color': JsonPropDefinition(type: 'string'),
          'radius': JsonPropDefinition(type: 'number'),
          'borderColor': JsonPropDefinition(type: 'string'),
          'borderWidth': JsonPropDefinition(type: 'number'),
          'alignment': JsonPropDefinition(type: 'string'),
        },
      ),
      'Center': const JsonComponentDefinition(
        description: 'Centers one child.',
      ),
      'SizedBox': const JsonComponentDefinition(
        description: 'Creates fixed empty space or constrains one child.',
        props: <String, JsonPropDefinition>{
          'width': JsonPropDefinition(type: 'number'),
          'height': JsonPropDefinition(type: 'number'),
        },
      ),
      'Button': const JsonComponentDefinition(
        description: 'Material elevated button that emits an event.',
        props: <String, JsonPropDefinition>{
          'label': JsonPropDefinition(type: 'string', required: true),
          'event': JsonPropDefinition(
            type: 'string',
            defaultValue: 'press',
            description: 'Event name emitted on tap.',
          ),
        },
      ),
      'Image': const JsonComponentDefinition(
        description: 'Displays network or asset image from a source string.',
        props: <String, JsonPropDefinition>{
          'src': JsonPropDefinition(type: 'string'),
          'url': JsonPropDefinition(type: 'string'),
          'width': JsonPropDefinition(type: 'number'),
          'height': JsonPropDefinition(type: 'number'),
          'fit': JsonPropDefinition(type: 'string'),
        },
      ),
    };

final Map<String, JsonActionDefinition> standardActionDefinitions =
    <String, JsonActionDefinition>{
      'noop': const JsonActionDefinition(description: 'No-op action.'),
    };

Map<String, JsonComponentBuilder> standardComponentBuilders() {
  return <String, JsonComponentBuilder>{
    'Text': (context) {
      final text = context.props['text']?.toString() ?? '';
      return Text(
        text,
        textAlign: _parseTextAlign(context.props['align']),
        maxLines: _toInt(context.props['maxLines']),
        overflow: _parseTextOverflow(context.props['overflow']),
        style: TextStyle(
          color: _parseColor(context.props['color']),
          fontSize: _toDouble(context.props['fontSize']),
          fontWeight: _parseFontWeight(context.props['fontWeight']),
        ),
      );
    },
    'Column': (context) {
      final spacing = _toDouble(context.props['spacing']) ?? 0;
      final children = _withSpacing(
        context.children,
        spacing: spacing,
        axis: Axis.vertical,
      );

      return Column(
        mainAxisSize: _parseMainAxisSize(context.props['mainAxisSize']),
        mainAxisAlignment: _parseMainAxisAlignment(
          context.props['mainAxisAlignment'],
        ),
        crossAxisAlignment: _parseCrossAxisAlignment(
          context.props['crossAxisAlignment'],
        ),
        children: children,
      );
    },
    'Row': (context) {
      final spacing = _toDouble(context.props['spacing']) ?? 0;
      final children = _withSpacing(
        context.children,
        spacing: spacing,
        axis: Axis.horizontal,
      );

      return Row(
        mainAxisSize: _parseMainAxisSize(context.props['mainAxisSize']),
        mainAxisAlignment: _parseMainAxisAlignment(
          context.props['mainAxisAlignment'],
        ),
        crossAxisAlignment: _parseCrossAxisAlignment(
          context.props['crossAxisAlignment'],
        ),
        children: children,
      );
    },
    'Container': (context) {
      final width = _toDouble(context.props['width']);
      final height = _toDouble(context.props['height']);
      final padding = _parseEdgeInsets(context.props['padding']);
      final margin = _parseEdgeInsets(context.props['margin']);
      final color = _parseColor(context.props['color']);
      final radius = _toDouble(context.props['radius']);
      final borderColor = _parseColor(context.props['borderColor']);
      final borderWidth = _toDouble(context.props['borderWidth']) ?? 0;
      final alignment = _parseAlignment(context.props['alignment']);

      final hasDecoration =
          color != null || radius != null || borderColor != null;

      Decoration? decoration;
      if (hasDecoration) {
        decoration = BoxDecoration(
          color: color,
          borderRadius: radius == null ? null : BorderRadius.circular(radius),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor, width: borderWidth),
        );
      }

      return Container(
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        alignment: alignment,
        decoration: decoration,
        child: _singleOrColumn(context.children),
      );
    },
    'Center': (context) {
      return Center(child: _singleOrColumn(context.children));
    },
    'SizedBox': (context) {
      return SizedBox(
        width: _toDouble(context.props['width']),
        height: _toDouble(context.props['height']),
        child: _singleOrColumn(context.children),
      );
    },
    'Button': (context) {
      final event = context.props['event']?.toString() ?? 'press';
      final label = context.props['label']?.toString() ?? 'Button';
      final child = context.children.isEmpty
          ? Text(label)
          : _singleOrColumn(context.children);

      return ElevatedButton(
        onPressed: context.loading ? null : () => context.emit(event),
        child: child,
      );
    },
    'Image': (context) {
      final source =
          context.props['src']?.toString() ??
          context.props['url']?.toString() ??
          '';
      final fit = _parseBoxFit(context.props['fit']);
      final width = _toDouble(context.props['width']);
      final height = _toDouble(context.props['height']);

      if (source.startsWith('http://') || source.startsWith('https://')) {
        return Image.network(source, fit: fit, width: width, height: height);
      }

      return Image.asset(source, fit: fit, width: width, height: height);
    },
  };
}

Widget _singleOrColumn(List<Widget> children) {
  if (children.isEmpty) return const SizedBox.shrink();
  if (children.length == 1) return children.first;
  return Column(mainAxisSize: MainAxisSize.min, children: children);
}

List<Widget> _withSpacing(
  List<Widget> children, {
  required double spacing,
  required Axis axis,
}) {
  if (spacing <= 0 || children.length <= 1) {
    return children;
  }

  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    spaced.add(children[i]);
    if (i == children.length - 1) continue;
    spaced.add(
      SizedBox(
        width: axis == Axis.horizontal ? spacing : null,
        height: axis == Axis.vertical ? spacing : null,
      ),
    );
  }
  return spaced;
}

EdgeInsetsGeometry? _parseEdgeInsets(dynamic raw) {
  if (raw == null) return null;

  if (raw is num) {
    final value = raw.toDouble();
    return EdgeInsets.all(value);
  }

  if (raw is List && raw.length == 4) {
    final left = _toDouble(raw[0]) ?? 0;
    final top = _toDouble(raw[1]) ?? 0;
    final right = _toDouble(raw[2]) ?? 0;
    final bottom = _toDouble(raw[3]) ?? 0;
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  if (raw is Map) {
    final left = _toDouble(raw['left']) ?? 0;
    final top = _toDouble(raw['top']) ?? 0;
    final right = _toDouble(raw['right']) ?? 0;
    final bottom = _toDouble(raw['bottom']) ?? 0;
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  return null;
}

Color? _parseColor(dynamic raw) {
  if (raw == null) return null;

  if (raw is int) {
    return Color(raw);
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return null;

  final normalized = text.startsWith('#') ? text.substring(1) : text;
  if (normalized.length == 6) {
    return Color(int.parse('FF$normalized', radix: 16));
  }
  if (normalized.length == 8) {
    return Color(int.parse(normalized, radix: 16));
  }

  return null;
}

FontWeight? _parseFontWeight(dynamic raw) {
  final value = raw?.toString();
  switch (value) {
    case 'w100':
    case '100':
      return FontWeight.w100;
    case 'w200':
    case '200':
      return FontWeight.w200;
    case 'w300':
    case '300':
      return FontWeight.w300;
    case 'w400':
    case '400':
    case 'normal':
      return FontWeight.w400;
    case 'w500':
    case '500':
      return FontWeight.w500;
    case 'w600':
    case '600':
      return FontWeight.w600;
    case 'w700':
    case '700':
    case 'bold':
      return FontWeight.w700;
    case 'w800':
    case '800':
      return FontWeight.w800;
    case 'w900':
    case '900':
      return FontWeight.w900;
    default:
      return null;
  }
}

TextAlign? _parseTextAlign(dynamic raw) {
  switch (raw?.toString()) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    case 'center':
      return TextAlign.center;
    case 'justify':
      return TextAlign.justify;
    default:
      return null;
  }
}

TextOverflow? _parseTextOverflow(dynamic raw) {
  switch (raw?.toString()) {
    case 'fade':
      return TextOverflow.fade;
    case 'ellipsis':
      return TextOverflow.ellipsis;
    case 'clip':
      return TextOverflow.clip;
    case 'visible':
      return TextOverflow.visible;
    default:
      return null;
  }
}

MainAxisSize _parseMainAxisSize(dynamic raw) {
  return raw?.toString() == 'min' ? MainAxisSize.min : MainAxisSize.max;
}

MainAxisAlignment _parseMainAxisAlignment(dynamic raw) {
  switch (raw?.toString()) {
    case 'start':
      return MainAxisAlignment.start;
    case 'end':
      return MainAxisAlignment.end;
    case 'center':
      return MainAxisAlignment.center;
    case 'spaceBetween':
      return MainAxisAlignment.spaceBetween;
    case 'spaceAround':
      return MainAxisAlignment.spaceAround;
    case 'spaceEvenly':
      return MainAxisAlignment.spaceEvenly;
    default:
      return MainAxisAlignment.start;
  }
}

CrossAxisAlignment _parseCrossAxisAlignment(dynamic raw) {
  switch (raw?.toString()) {
    case 'start':
      return CrossAxisAlignment.start;
    case 'end':
      return CrossAxisAlignment.end;
    case 'center':
      return CrossAxisAlignment.center;
    case 'stretch':
      return CrossAxisAlignment.stretch;
    default:
      return CrossAxisAlignment.center;
  }
}

AlignmentGeometry? _parseAlignment(dynamic raw) {
  switch (raw?.toString()) {
    case 'topLeft':
      return Alignment.topLeft;
    case 'topCenter':
      return Alignment.topCenter;
    case 'topRight':
      return Alignment.topRight;
    case 'centerLeft':
      return Alignment.centerLeft;
    case 'center':
      return Alignment.center;
    case 'centerRight':
      return Alignment.centerRight;
    case 'bottomLeft':
      return Alignment.bottomLeft;
    case 'bottomCenter':
      return Alignment.bottomCenter;
    case 'bottomRight':
      return Alignment.bottomRight;
    default:
      return null;
  }
}

BoxFit? _parseBoxFit(dynamic raw) {
  switch (raw?.toString()) {
    case 'fill':
      return BoxFit.fill;
    case 'contain':
      return BoxFit.contain;
    case 'cover':
      return BoxFit.cover;
    case 'fitWidth':
      return BoxFit.fitWidth;
    case 'fitHeight':
      return BoxFit.fitHeight;
    case 'none':
      return BoxFit.none;
    case 'scaleDown':
      return BoxFit.scaleDown;
    default:
      return null;
  }
}

double? _toDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

int? _toInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}
