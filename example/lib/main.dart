import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

const String _initialStylePresetId = String.fromEnvironment(
  'STYLE_PRESET',
  defaultValue: 'clean',
);

void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  late final List<ShowcaseVisualStyle> _styles = kShowcaseStyles;
  late final JsonCatalog _catalog = _buildCatalog();
  late final JsonRegistry _registry = _buildRegistry();
  late final List<ShowcaseCase> _cases = _buildCases();

  late ShowcaseVisualStyle _selectedStyle = _findStyle(_initialStylePresetId);
  late ShowcaseCase _selectedCase = _cases.first;
  late JsonRenderSpec _activeSpec = _selectedCase.spec;

  final JsonSpecStreamCompiler _streamCompiler = JsonSpecStreamCompiler();

  Map<String, dynamic> _latestState = <String, dynamic>{};
  final List<String> _eventLog = <String>[];
  bool _isStreaming = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'flutter_json_render Showcase',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _selectedStyle.seedColor),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_json_render Showcase'),
          actions: <Widget>[
            TextButton.icon(
              onPressed: _resetCase,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            if (isWide) {
              return Row(
                children: <Widget>[
                  SizedBox(width: 420, child: _buildControlPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildPreviewPanel()),
                ],
              );
            }

            return Column(
              children: <Widget>[
                SizedBox(height: 420, child: _buildControlPanel()),
                const Divider(height: 1),
                Expanded(child: _buildPreviewPanel()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    final stateText = const JsonEncoder.withIndent('  ').convert(_latestState);
    final specJson = <String, dynamic>{
      ..._activeSpec.toJson(),
      'style': _selectedStyle.id,
    };
    final specText = const JsonEncoder.withIndent('  ').convert(specJson);
    final promptText = _catalog.prompt(
      options: JsonPromptOptions(
        includeProps: true,
        includeExamples: false,
        includeActions: true,
        includeStyles: true,
        selectedStyleId: _selectedStyle.id,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<ShowcaseCase>(
            value: _selectedCase,
            decoration: const InputDecoration(
              labelText: 'Scenario',
              border: OutlineInputBorder(),
            ),
            items: _cases
                .map(
                  (entry) => DropdownMenuItem<ShowcaseCase>(
                    value: entry,
                    child: Text(entry.title),
                  ),
                )
                .toList(growable: false),
            onChanged: (next) {
              if (next == null) return;
              setState(() {
                _selectedCase = next;
                _activeSpec = _selectedCase.spec;
                _latestState = _activeSpec.state;
                _eventLog.clear();
                _isStreaming = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(_selectedCase.description),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DropdownButtonFormField<ShowcaseVisualStyle>(
            value: _selectedStyle,
            decoration: const InputDecoration(
              labelText: 'Style Preset',
              border: OutlineInputBorder(),
            ),
            items: _styles
                .map(
                  (entry) => DropdownMenuItem<ShowcaseVisualStyle>(
                    value: entry,
                    child: Text('${entry.name} (${entry.id})'),
                  ),
                )
                .toList(growable: false),
            onChanged: (next) {
              if (next == null) return;
              setState(() {
                _selectedStyle = next;
                _eventLog.add('[style] ${_selectedStyle.id}');
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _resetCase,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset Scenario'),
              ),
              FilledButton.icon(
                onPressed: _selectedCase.streamLines.isEmpty || _isStreaming
                    ? null
                    : _runStreamSimulation,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Stream'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: <Widget>[
                const TabBar(
                  tabs: <Tab>[
                    Tab(text: 'State'),
                    Tab(text: 'Spec'),
                    Tab(text: 'Prompt'),
                    Tab(text: 'Log'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _textPane(stateText),
                      _textPane(specText),
                      _textPane(promptText),
                      _textPane(
                        _eventLog.isEmpty
                            ? 'No events yet.'
                            : _eventLog.join('\n'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    final style = _selectedStyle;
    return ColoredBox(
      color: style.previewBackground,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: style.panelBorder),
            ),
            color: style.panelBackground,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: JsonRenderer(
                  spec: _activeSpec,
                  registry: _registry,
                  styleId: _selectedStyle.id,
                  onStateChanged: (state) {
                    setState(() {
                      _latestState = state;
                    });
                  },
                  onError: (error, stackTrace, context) {
                    setState(() {
                      _eventLog.add('[error][$context] $error');
                      _eventLog.add('[error][stack] $stackTrace');
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textPane(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        content,
        style: const TextStyle(fontFamily: 'monospace', height: 1.4),
      ),
    );
  }

  void _resetCase() {
    setState(() {
      _isStreaming = false;
      _activeSpec = _selectedCase.spec;
      _latestState = _activeSpec.state;
      _eventLog
        ..clear()
        ..add('[system] Scenario reset: ${_selectedCase.title}')
        ..add('[system] Style: ${_selectedStyle.id}');
    });
  }

  Future<void> _runStreamSimulation() async {
    if (_selectedCase.streamLines.isEmpty) {
      return;
    }

    setState(() {
      _isStreaming = true;
      _eventLog.add('[stream] Starting JSONL patch stream...');
    });

    _streamCompiler.reset(initialSpec: _selectedCase.spec);

    for (final line in _selectedCase.streamLines) {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final pushed = _streamCompiler.push('$line\n');
        if (!mounted) return;
        setState(() {
          if (pushed.result != null) {
            _activeSpec = pushed.result!;
            _latestState = _activeSpec.state;
          }
          _eventLog.add('[stream] $line');
        });
      } catch (error) {
        setState(() {
          _eventLog.add('[stream][error] $error');
        });
      }
    }

    setState(() {
      _isStreaming = false;
      _eventLog.add('[stream] Completed.');
    });
  }

  ShowcaseVisualStyle _findStyle(String styleId) {
    for (final style in _styles) {
      if (style.id == styleId) {
        return style;
      }
    }
    return _styles.first;
  }

  JsonCatalog _buildCatalog() {
    return JsonCatalog(
      components: <String, JsonComponentDefinition>{
        ...standardComponentDefinitions,
        'Panel': const JsonComponentDefinition(
          description: 'Card-like visual container.',
          props: <String, JsonPropDefinition>{
            'title': JsonPropDefinition(type: 'string', required: true),
          },
        ),
        'StatusChip': const JsonComponentDefinition(
          description: 'Compact status pill with color variant.',
          props: <String, JsonPropDefinition>{
            'label': JsonPropDefinition(type: 'string', required: true),
            'variant': JsonPropDefinition(
              type: 'string',
              enumValues: <String>['neutral', 'success', 'warning', 'danger'],
            ),
          },
        ),
        'ProgressBar': const JsonComponentDefinition(
          description: 'Simple horizontal progress bar from 0 to 1.',
          props: <String, JsonPropDefinition>{
            'value': JsonPropDefinition(type: 'number', required: true),
            'color': JsonPropDefinition(type: 'string'),
          },
        ),
      },
      styles: {
        for (final style in _styles)
          style.id: JsonStyleDefinition(
            displayName: style.name,
            description: style.description,
            guidance: style.promptGuidance,
          ),
      },
      actions: <String, JsonActionDefinition>{
        ...standardActionDefinitions,
        'increment': const JsonActionDefinition(
          description: 'Increase count by 1.',
        ),
        'decrement': const JsonActionDefinition(
          description: 'Decrease count by 1.',
        ),
        'toggle_hint': const JsonActionDefinition(
          description: 'Toggle hint visibility.',
        ),
        'add_item': const JsonActionDefinition(
          description: 'Add random todo item.',
        ),
        'toggle_item': const JsonActionDefinition(
          description: 'Toggle done state for item index.',
          params: <String, JsonPropDefinition>{
            'index': JsonPropDefinition(type: 'number', required: true),
          },
        ),
        'remove_item': const JsonActionDefinition(
          description: 'Remove item by index.',
          params: <String, JsonPropDefinition>{
            'index': JsonPropDefinition(type: 'number', required: true),
          },
        ),
        'cycle_growth': const JsonActionDefinition(
          description: 'Rotate growth values between positive and negative.',
        ),
        'refresh_metrics': const JsonActionDefinition(
          description: 'Simulate async server refresh of dashboard metrics.',
        ),
      },
    );
  }

  JsonRegistry _buildRegistry() {
    final random = Random();

    return defineRegistry(
      components: <String, JsonComponentBuilder>{
        ...standardComponentBuilders(),
        'Panel': (ctx) {
          final style = _selectedStyle;
          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: style.panelBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: style.panelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  ctx.props['title']?.toString() ?? 'Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: style.textPrimary,
                  ),
                ),
                if (ctx.children.isNotEmpty) const SizedBox(height: 12),
                ...ctx.children,
              ],
            ),
          );
        },
        'StatusChip': (ctx) {
          final style = _selectedStyle;
          final variant = ctx.props['variant']?.toString() ?? 'neutral';
          final pair = _chipStyle(style, variant);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pair.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: pair.border),
            ),
            child: Text(
              ctx.props['label']?.toString() ?? '',
              style: TextStyle(
                color: pair.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
        'ProgressBar': (ctx) {
          final style = _selectedStyle;
          final valueRaw = ctx.props['value'];
          final value = (valueRaw is num ? valueRaw.toDouble() : 0.0).clamp(
            0.0,
            1.0,
          );
          final colorHex = ctx.props['color']?.toString();
          final color = _safeColor(colorHex) ?? style.accent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: style.trackBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          );
        },
      },
      actions: <String, JsonActionHandler>{
        'noop': (_) {},
        'increment': (ctx) {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            next['count'] = ((prev['count'] as num?) ?? 0) + 1;
            return next;
          });
          setState(() {
            _eventLog.add('[action] increment');
          });
        },
        'decrement': (ctx) {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            next['count'] = ((prev['count'] as num?) ?? 0) - 1;
            return next;
          });
          setState(() {
            _eventLog.add('[action] decrement');
          });
        },
        'toggle_hint': (ctx) {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            next['showHint'] = !((prev['showHint'] as bool?) ?? false);
            return next;
          });
          setState(() {
            _eventLog.add('[action] toggle_hint');
          });
        },
        'add_item': (ctx) {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            final items = ((prev['items'] as List?) ?? <dynamic>[])
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: true);
            items.add(<String, dynamic>{
              'name': 'Task #${100 + random.nextInt(900)}',
              'done': false,
            });
            next['items'] = items;
            return next;
          });
          setState(() {
            _eventLog.add('[action] add_item');
          });
        },
        'toggle_item': (ctx) {
          final index = (ctx.params?['index'] as num?)?.toInt();
          if (index == null) return;

          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            final items = ((prev['items'] as List?) ?? <dynamic>[])
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: true);
            if (index < 0 || index >= items.length) {
              return next;
            }
            final item = items[index];
            item['done'] = !((item['done'] as bool?) ?? false);
            next['items'] = items;
            return next;
          });
          setState(() {
            _eventLog.add('[action] toggle_item(index: $index)');
          });
        },
        'remove_item': (ctx) {
          final index = (ctx.params?['index'] as num?)?.toInt();
          if (index == null) return;

          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            final items = ((prev['items'] as List?) ?? <dynamic>[])
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: true);
            if (index < 0 || index >= items.length) {
              return next;
            }
            items.removeAt(index);
            next['items'] = items;
            return next;
          });
          setState(() {
            _eventLog.add('[action] remove_item(index: $index)');
          });
        },
        'cycle_growth': (ctx) {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            final current = (prev['growth'] as num?)?.toDouble() ?? 0;
            if (current < 0) {
              next['growth'] = 6.4;
              next['progress'] = 0.74;
            } else if (current < 5) {
              next['growth'] = 14.1;
              next['progress'] = 0.93;
            } else {
              next['growth'] = -4.2;
              next['progress'] = 0.43;
            }
            return next;
          });
          setState(() {
            _eventLog.add('[action] cycle_growth');
          });
        },
        'refresh_metrics': (ctx) async {
          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            next['status'] = 'loading';
            return next;
          });

          await Future<void>.delayed(const Duration(milliseconds: 900));

          ctx.setStateModel((prev) {
            final next = <String, dynamic>{...prev};
            next['status'] = 'ready';
            next['lastUpdated'] = DateTime.now().toIso8601String();
            next['count'] = ((prev['count'] as num?) ?? 0) + 3;
            return next;
          });
          setState(() {
            _eventLog.add('[action] refresh_metrics complete');
          });
        },
      },
    );
  }

  List<ShowcaseCase> _buildCases() {
    return <ShowcaseCase>[
      ShowcaseCase(
        id: 'counter',
        title: '1) Counter + Visibility',
        description:
            r'Basic action bindings, state reads ($state), and visible condition toggle.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'panel',
          'state': <String, dynamic>{'count': 2, 'showHint': false},
          'elements': <String, dynamic>{
            'panel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Interactive Counter'},
              'children': <String>['countText', 'buttons', 'hint'],
            },
            'countText': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{r'$state': '/count'},
                'fontSize': 42,
                'fontWeight': '700',
              },
            },
            'buttons': <String, dynamic>{
              'type': 'Row',
              'props': <String, dynamic>{
                'spacing': 8,
                'runSpacing': 8,
                'overflow': 'wrap',
              },
              'children': <String>['dec', 'inc', 'toggle'],
            },
            'dec': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': '-1'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'decrement'},
              },
            },
            'inc': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': '+1'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'increment'},
              },
            },
            'toggle': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': 'Toggle Hint'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'toggle_hint'},
              },
            },
            'hint': <String, dynamic>{
              'type': 'Text',
              'visible': <String, dynamic>{r'$state': '/showHint', 'eq': true},
              'props': <String, dynamic>{
                'text': 'Hint: This node is controlled by `visible`.',
                'color': '#0F766E',
              },
            },
          },
        }),
      ),
      ShowcaseCase(
        id: 'repeat',
        title: '2) Repeat + Item Scope',
        description:
            r'repeat.statePath with $item/$index expressions and per-row action params.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'todoPanel',
          'state': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Write docs', 'done': true},
              <String, dynamic>{'name': 'Add tests', 'done': false},
              <String, dynamic>{'name': 'Ship package', 'done': false},
            ],
          },
          'elements': <String, dynamic>{
            'todoPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Todo List'},
              'children': <String>['repeater', 'controls'],
            },
            'repeater': <String, dynamic>{
              'type': 'Column',
              'props': <String, dynamic>{'spacing': 8},
              'repeat': <String, dynamic>{'statePath': '/items'},
              'children': <String>['row'],
            },
            'row': <String, dynamic>{
              'type': 'Container',
              'props': <String, dynamic>{
                'padding': 10,
                'radius': 10,
                'borderColor': '#CBD5E1',
                'borderWidth': 1,
              },
              'children': <String>['line'],
            },
            'line': <String, dynamic>{
              'type': 'Row',
              'props': <String, dynamic>{
                'spacing': 8,
                'runSpacing': 8,
                'overflow': 'wrap',
              },
              'children': <String>[
                'name',
                'doneChip',
                'toggleBtn',
                'removeBtn',
              ],
            },
            'name': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{r'$item': 'name'},
              },
            },
            'doneChip': <String, dynamic>{
              'type': 'StatusChip',
              'visible': <String, dynamic>{r'$item': 'done', 'eq': true},
              'props': <String, dynamic>{'label': 'DONE', 'variant': 'success'},
            },
            'toggleBtn': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{
                'label': <String, dynamic>{
                  r'$cond': <String, dynamic>{r'$item': 'done', 'eq': true},
                  r'$then': 'Undo',
                  r'$else': 'Done',
                },
              },
              'on': <String, dynamic>{
                'press': <String, dynamic>{
                  'action': 'toggle_item',
                  'params': <String, dynamic>{
                    'index': <String, dynamic>{r'$index': true},
                  },
                },
              },
            },
            'removeBtn': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': 'Remove'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{
                  'action': 'remove_item',
                  'params': <String, dynamic>{
                    'index': <String, dynamic>{r'$index': true},
                  },
                },
              },
            },
            'controls': <String, dynamic>{
              'type': 'Row',
              'props': <String, dynamic>{'spacing': 8},
              'children': <String>['addButton'],
            },
            'addButton': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': 'Add Item'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'add_item'},
              },
            },
          },
        }),
      ),
      ShowcaseCase(
        id: 'cond',
        title: '3) Dynamic Props + Progress',
        description:
            r'Uses $cond for text/color and demonstrates custom ProgressBar component.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'growthPanel',
          'state': <String, dynamic>{'growth': -4.2, 'progress': 0.43},
          'elements': <String, dynamic>{
            'growthPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Growth Monitor'},
              'children': <String>['trend', 'progress', 'cycle'],
            },
            'trend': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{
                  r'$cond': <String, dynamic>{r'$state': '/growth', 'gte': 0},
                  r'$then': 'Trend: Positive',
                  r'$else': 'Trend: Negative',
                },
                'fontSize': 22,
                'fontWeight': '700',
                'color': <String, dynamic>{
                  r'$cond': <String, dynamic>{r'$state': '/growth', 'gte': 0},
                  r'$then': '#15803D',
                  r'$else': '#B91C1C',
                },
              },
            },
            'progress': <String, dynamic>{
              'type': 'ProgressBar',
              'props': <String, dynamic>{
                'value': <String, dynamic>{r'$state': '/progress'},
                'color': <String, dynamic>{
                  r'$cond': <String, dynamic>{r'$state': '/growth', 'gte': 0},
                  r'$then': '#0F766E',
                  r'$else': '#B91C1C',
                },
              },
            },
            'cycle': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': 'Cycle Growth State'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'cycle_growth'},
              },
            },
          },
        }),
      ),
      ShowcaseCase(
        id: 'async',
        title: '4) Async Action',
        description:
            'Asynchronous action updates loading state, then commits final values.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'asyncPanel',
          'state': <String, dynamic>{
            'status': 'idle',
            'lastUpdated': '-',
            'count': 0,
          },
          'elements': <String, dynamic>{
            'asyncPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Async Refresh'},
              'children': <String>[
                'statusRow',
                'lastUpdated',
                'count',
                'refresh',
              ],
            },
            'statusRow': <String, dynamic>{
              'type': 'Row',
              'props': <String, dynamic>{'spacing': 8},
              'children': <String>['statusLabel', 'statusChip'],
            },
            'statusLabel': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{'text': 'Status:'},
            },
            'statusChip': <String, dynamic>{
              'type': 'StatusChip',
              'props': <String, dynamic>{
                'label': <String, dynamic>{r'$state': '/status'},
                'variant': <String, dynamic>{
                  r'$cond': <String, dynamic>{
                    r'$state': '/status',
                    'eq': 'ready',
                  },
                  r'$then': 'success',
                  r'$else': <String, dynamic>{
                    r'$cond': <String, dynamic>{
                      r'$state': '/status',
                      'eq': 'loading',
                    },
                    r'$then': 'warning',
                    r'$else': 'neutral',
                  },
                },
              },
            },
            'lastUpdated': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{
                  r'$cond': <String, dynamic>{
                    r'$state': '/lastUpdated',
                    'eq': '-',
                  },
                  r'$then': 'Last updated: never',
                  r'$else': <String, dynamic>{r'$state': '/lastUpdated'},
                },
              },
            },
            'count': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{r'$state': '/count'},
              },
            },
            'refresh': <String, dynamic>{
              'type': 'Button',
              'props': <String, dynamic>{'label': 'Refresh Metrics'},
              'on': <String, dynamic>{
                'press': <String, dynamic>{'action': 'refresh_metrics'},
              },
            },
          },
        }),
      ),
      ShowcaseCase(
        id: 'stream',
        title: '5) Streamed JSONL Patch',
        description:
            'Simulates server-sent JSONL patches using JsonSpecStreamCompiler.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'streamPanel',
          'state': <String, dynamic>{'status': 'starting'},
          'elements': <String, dynamic>{
            'streamPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Streaming Spec'},
              'children': <String>['statusText'],
            },
            'statusText': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': <String, dynamic>{r'$state': '/status'},
              },
            },
          },
        }),
        streamLines: <String>[
          '{"op":"replace","path":"/state/status","value":"creating widgets"}',
          '{"op":"add","path":"/elements/subtitle","value":{"type":"Text","props":{"text":"Patches are applied incrementally.","color":"#0F766E"}}}',
          '{"op":"add","path":"/elements/streamPanel/children/1","value":"subtitle"}',
          '{"op":"replace","path":"/state/status","value":"done"}',
          '{"op":"add","path":"/elements/chip","value":{"type":"StatusChip","props":{"label":"STREAM COMPLETE","variant":"success"}}}',
          '{"op":"add","path":"/elements/streamPanel/children/2","value":"chip"}',
        ],
      ),
    ];
  }
}

class ShowcaseCase {
  const ShowcaseCase({
    required this.id,
    required this.title,
    required this.description,
    required this.spec,
    this.streamLines = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final JsonRenderSpec spec;
  final List<String> streamLines;
}

class ShowcaseChipStyle {
  const ShowcaseChipStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

class ShowcaseVisualStyle {
  const ShowcaseVisualStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.promptGuidance,
    required this.seedColor,
    required this.previewBackground,
    required this.panelBackground,
    required this.panelBorder,
    required this.textPrimary,
    required this.accent,
    required this.trackBackground,
    required this.neutralChip,
    required this.successChip,
    required this.warningChip,
    required this.dangerChip,
  });

  final String id;
  final String name;
  final String description;
  final String promptGuidance;
  final Color seedColor;
  final Color previewBackground;
  final Color panelBackground;
  final Color panelBorder;
  final Color textPrimary;
  final Color accent;
  final Color trackBackground;
  final ShowcaseChipStyle neutralChip;
  final ShowcaseChipStyle successChip;
  final ShowcaseChipStyle warningChip;
  final ShowcaseChipStyle dangerChip;
}

const List<ShowcaseVisualStyle> kShowcaseStyles = <ShowcaseVisualStyle>[
  ShowcaseVisualStyle(
    id: 'clean',
    name: 'Clean',
    description: 'Neutral colors and subtle borders for productivity UIs.',
    promptGuidance:
        'Use restrained color. Keep spacing balanced and typography straightforward.',
    seedColor: Color(0xFF0A5B9E),
    previewBackground: Color(0xFFF1F5F9),
    panelBackground: Color(0xFFFFFFFF),
    panelBorder: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    accent: Color(0xFF0F766E),
    trackBackground: Color(0xFFE2E8F0),
    neutralChip: ShowcaseChipStyle(
      background: Color(0xFFE2E8F0),
      border: Color(0xFFCBD5E1),
      foreground: Color(0xFF334155),
    ),
    successChip: ShowcaseChipStyle(
      background: Color(0xFFDCFCE7),
      border: Color(0xFF86EFAC),
      foreground: Color(0xFF166534),
    ),
    warningChip: ShowcaseChipStyle(
      background: Color(0xFFFEF3C7),
      border: Color(0xFFFCD34D),
      foreground: Color(0xFF92400E),
    ),
    dangerChip: ShowcaseChipStyle(
      background: Color(0xFFFEE2E2),
      border: Color(0xFFFCA5A5),
      foreground: Color(0xFF991B1B),
    ),
  ),
  ShowcaseVisualStyle(
    id: 'midnight',
    name: 'Midnight',
    description: 'Dark surfaces with cyan accents for data-heavy screens.',
    promptGuidance:
        'Prefer strong contrast. Use dark panels, bright accents, and compact spacing.',
    seedColor: Color(0xFF155E75),
    previewBackground: Color(0xFF020617),
    panelBackground: Color(0xFF0F172A),
    panelBorder: Color(0xFF1E293B),
    textPrimary: Color(0xFFE2E8F0),
    accent: Color(0xFF06B6D4),
    trackBackground: Color(0xFF1E293B),
    neutralChip: ShowcaseChipStyle(
      background: Color(0xFF1E293B),
      border: Color(0xFF334155),
      foreground: Color(0xFFE2E8F0),
    ),
    successChip: ShowcaseChipStyle(
      background: Color(0xFF052E2B),
      border: Color(0xFF0F766E),
      foreground: Color(0xFF99F6E4),
    ),
    warningChip: ShowcaseChipStyle(
      background: Color(0xFF422006),
      border: Color(0xFFA16207),
      foreground: Color(0xFFFDE68A),
    ),
    dangerChip: ShowcaseChipStyle(
      background: Color(0xFF450A0A),
      border: Color(0xFFB91C1C),
      foreground: Color(0xFFFCA5A5),
    ),
  ),
  ShowcaseVisualStyle(
    id: 'sunset',
    name: 'Sunset',
    description: 'Warm cards with orange and rose accents for marketing feel.',
    promptGuidance:
        'Use energetic warm colors, rounded containers, and expressive labels.',
    seedColor: Color(0xFFEA580C),
    previewBackground: Color(0xFFFFF7ED),
    panelBackground: Color(0xFFFFFBF5),
    panelBorder: Color(0xFFFED7AA),
    textPrimary: Color(0xFF7C2D12),
    accent: Color(0xFFEA580C),
    trackBackground: Color(0xFFFED7AA),
    neutralChip: ShowcaseChipStyle(
      background: Color(0xFFFFEDD5),
      border: Color(0xFFFDBA74),
      foreground: Color(0xFF9A3412),
    ),
    successChip: ShowcaseChipStyle(
      background: Color(0xFFDCFCE7),
      border: Color(0xFF86EFAC),
      foreground: Color(0xFF166534),
    ),
    warningChip: ShowcaseChipStyle(
      background: Color(0xFFFEF3C7),
      border: Color(0xFFFCD34D),
      foreground: Color(0xFF92400E),
    ),
    dangerChip: ShowcaseChipStyle(
      background: Color(0xFFFFE4E6),
      border: Color(0xFFFDA4AF),
      foreground: Color(0xFF9F1239),
    ),
  ),
];

ShowcaseChipStyle _chipStyle(ShowcaseVisualStyle style, String variant) {
  switch (variant) {
    case 'success':
      return style.successChip;
    case 'warning':
      return style.warningChip;
    case 'danger':
      return style.dangerChip;
    default:
      return style.neutralChip;
  }
}

Color? _safeColor(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final text = raw.startsWith('#') ? raw.substring(1) : raw;
  if (text.length == 6) {
    return Color(int.parse('FF$text', radix: 16));
  }
  if (text.length == 8) {
    return Color(int.parse(text, radix: 16));
  }
  return null;
}
