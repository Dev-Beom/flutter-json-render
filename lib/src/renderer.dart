import 'dart:async';

import 'package:flutter/widgets.dart';

import 'json_path.dart';
import 'registry.dart';
import 'resolver.dart';
import 'spec.dart';
import 'visibility.dart';

class JsonRenderer extends StatefulWidget {
  const JsonRenderer({
    super.key,
    required this.registry,
    this.spec,
    this.state,
    this.styleId,
    this.loading = false,
    this.placeholder,
    this.onStateChanged,
    this.onError,
  });

  final JsonRenderSpec? spec;
  final JsonRegistry registry;
  final Map<String, dynamic>? state;
  final String? styleId;
  final bool loading;
  final Widget? placeholder;
  final ValueChanged<Map<String, dynamic>>? onStateChanged;
  final void Function(Object error, StackTrace stackTrace, String context)?
  onError;

  @override
  State<JsonRenderer> createState() => _JsonRendererState();
}

class _JsonRendererState extends State<JsonRenderer> {
  late Map<String, dynamic> _state;

  @override
  void initState() {
    super.initState();
    _state = _buildInitialState(widget.spec, widget.state);
  }

  @override
  void didUpdateWidget(covariant JsonRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final specChanged = oldWidget.spec != widget.spec;
    final externalStateChanged = oldWidget.state != widget.state;
    if (specChanged || externalStateChanged) {
      _state = _buildInitialState(widget.spec, widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    final rootElement = spec.elements[spec.root];
    if (rootElement == null) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return _buildElement(
      spec: spec,
      key: spec.root,
      element: rootElement,
      styleId: _resolveStyleId(spec),
      repeatScope: null,
      ancestry: <String>{},
    );
  }

  String? _resolveStyleId(JsonRenderSpec spec) {
    final override = widget.styleId;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return spec.style;
  }

  Map<String, dynamic> _buildInitialState(
    JsonRenderSpec? spec,
    Map<String, dynamic>? externalState,
  ) {
    final merged = <String, dynamic>{};

    if (spec?.state case final specState?) {
      merged.addAll(deepCopyMap(specState));
    }

    if (externalState != null) {
      merged.addAll(deepCopyMap(externalState));
    }

    return merged;
  }

  Widget _buildElement({
    required JsonRenderSpec spec,
    required String key,
    required JsonElement element,
    required String? styleId,
    required JsonRepeatScope? repeatScope,
    required Set<String> ancestry,
  }) {
    if (ancestry.contains(key)) {
      _reportError(
        StateError('Circular element reference detected for "$key".'),
        StackTrace.current,
        'build:$key',
      );
      return const SizedBox.shrink();
    }

    final nextAncestry = <String>{...ancestry, key};
    final resolutionContext = JsonResolutionContext(
      state: _state,
      repeatScope: repeatScope,
    );

    final isVisible = evaluateVisibility(element.visible, resolutionContext);
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final resolvedProps = resolveProps(element.props, resolutionContext);

    final children = <Widget>[];

    if (element.repeat != null) {
      children.addAll(
        _buildRepeatedChildren(
          spec: spec,
          element: element,
          styleId: styleId,
          ancestry: nextAncestry,
        ),
      );
    } else {
      for (final childKey in element.children) {
        final childElement = spec.elements[childKey];
        if (childElement == null) {
          _reportError(
            StateError(
              'Missing child element "$childKey" referenced by "$key".',
            ),
            StackTrace.current,
            'child:$key->$childKey',
          );
          continue;
        }

        children.add(
          _buildElement(
            spec: spec,
            key: childKey,
            element: childElement,
            styleId: styleId,
            repeatScope: repeatScope,
            ancestry: nextAncestry,
          ),
        );
      }
    }

    final componentBuilder =
        widget.registry.components[element.type] ?? widget.registry.fallback;
    if (componentBuilder == null) {
      return const SizedBox.shrink();
    }

    void emit(String event) {
      _emit(
        elementKey: key,
        element: element,
        event: event,
        styleId: styleId,
        repeatScope: repeatScope,
      );
    }

    final componentContext = JsonComponentContext(
      key: key,
      element: element,
      props: resolvedProps,
      children: children,
      emit: emit,
      state: _state,
      styleId: styleId,
      repeatScope: repeatScope,
      loading: widget.loading,
    );

    try {
      return componentBuilder(componentContext);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'component:${element.type}#$key');
      return const SizedBox.shrink();
    }
  }

  List<Widget> _buildRepeatedChildren({
    required JsonRenderSpec spec,
    required JsonElement element,
    required String? styleId,
    required Set<String> ancestry,
  }) {
    final repeat = element.repeat;
    if (repeat == null) return const <Widget>[];

    final collection = getByPath(_state, repeat.statePath);
    if (collection is! List) {
      return const <Widget>[];
    }

    final widgets = <Widget>[];

    for (var index = 0; index < collection.length; index++) {
      final item = collection[index];
      final scope = JsonRepeatScope(
        item: item,
        index: index,
        basePath: appendPath(repeat.statePath, index.toString()),
      );

      for (final childKey in element.children) {
        final childElement = spec.elements[childKey];
        if (childElement == null) {
          _reportError(
            StateError('Missing repeated child "$childKey".'),
            StackTrace.current,
            'repeat:${element.type}->$childKey',
          );
          continue;
        }

        widgets.add(
          _buildElement(
            spec: spec,
            key: childKey,
            element: childElement,
            styleId: styleId,
            repeatScope: scope,
            ancestry: ancestry,
          ),
        );
      }
    }

    return widgets;
  }

  void _emit({
    required String elementKey,
    required JsonElement element,
    required String event,
    required String? styleId,
    required JsonRepeatScope? repeatScope,
  }) {
    final bindings = element.on[event];
    if (bindings == null || bindings.isEmpty) {
      return;
    }

    for (final binding in bindings) {
      final handler = widget.registry.actions[binding.action];
      if (handler == null) {
        _reportError(
          StateError('No action handler for "${binding.action}".'),
          StackTrace.current,
          'action:$elementKey:$event',
        );
        continue;
      }

      final resolutionContext = JsonResolutionContext(
        state: _state,
        repeatScope: repeatScope,
      );

      final params = binding.params == null
          ? null
          : resolveValue(binding.params, resolutionContext)
                as Map<String, dynamic>?;

      void setStateModel(JsonStateUpdater updater) {
        if (!mounted) return;
        setState(() {
          _state = updater(deepCopyMap(_state));
        });
        widget.onStateChanged?.call(deepCopyMap(_state));
      }

      final actionContext = JsonActionContext(
        key: elementKey,
        event: event,
        binding: binding,
        params: params,
        state: deepCopyMap(_state),
        setStateModel: setStateModel,
        styleId: styleId,
        repeatScope: repeatScope,
      );

      try {
        final result = handler(actionContext);
        if (result is Future<void>) {
          unawaited(
            result.catchError((Object error, StackTrace stackTrace) {
              _reportError(error, stackTrace, 'action:${binding.action}');
            }),
          );
        }
      } catch (error, stackTrace) {
        _reportError(error, stackTrace, 'action:${binding.action}');
      }
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String context) {
    widget.onError?.call(error, stackTrace, context);
  }
}
