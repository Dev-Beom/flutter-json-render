import 'dart:async';

import 'package:flutter/widgets.dart';

import 'spec.dart';

typedef JsonStateUpdater =
    Map<String, dynamic> Function(Map<String, dynamic> current);
typedef JsonComponentBuilder = Widget Function(JsonComponentContext context);
typedef JsonActionHandler = FutureOr<void> Function(JsonActionContext context);

class JsonComponentContext {
  const JsonComponentContext({
    required this.key,
    required this.element,
    required this.props,
    required this.children,
    required this.emit,
    required this.state,
    this.repeatScope,
    this.loading = false,
  });

  final String key;
  final JsonElement element;
  final Map<String, dynamic> props;
  final List<Widget> children;
  final void Function(String event) emit;
  final Map<String, dynamic> state;
  final JsonRepeatScope? repeatScope;
  final bool loading;
}

class JsonActionContext {
  const JsonActionContext({
    required this.key,
    required this.event,
    required this.binding,
    required this.params,
    required this.state,
    required this.setStateModel,
    this.repeatScope,
  });

  final String key;
  final String event;
  final JsonActionBinding binding;
  final Map<String, dynamic>? params;
  final Map<String, dynamic> state;
  final void Function(JsonStateUpdater updater) setStateModel;
  final JsonRepeatScope? repeatScope;
}

class JsonRepeatScope {
  const JsonRepeatScope({
    required this.item,
    required this.index,
    required this.basePath,
  });

  final dynamic item;
  final int index;
  final String basePath;
}

class JsonRegistry {
  const JsonRegistry({
    required this.components,
    this.actions = const <String, JsonActionHandler>{},
    this.fallback,
  });

  final Map<String, JsonComponentBuilder> components;
  final Map<String, JsonActionHandler> actions;
  final JsonComponentBuilder? fallback;
}

JsonRegistry defineRegistry({
  required Map<String, JsonComponentBuilder> components,
  Map<String, JsonActionHandler> actions = const <String, JsonActionHandler>{},
  JsonComponentBuilder? fallback,
}) {
  return JsonRegistry(
    components: components,
    actions: actions,
    fallback: fallback,
  );
}
