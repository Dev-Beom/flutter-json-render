import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_json_render/flutter_json_render.dart';

const String _initialStylePresetId = String.fromEnvironment(
  'STYLE_PRESET',
  defaultValue: 'clean',
);
const String _initialScenarioId = String.fromEnvironment(
  'SCENARIO',
  defaultValue: 'counter',
);
const bool _autoRunStream = bool.fromEnvironment(
  'AUTO_RUN_STREAM',
  defaultValue: false,
);
const bool _captureMode = bool.fromEnvironment(
  'CAPTURE_MODE',
  defaultValue: false,
);
const int _streamStepDelayMs = int.fromEnvironment(
  'STREAM_STEP_DELAY_MS',
  defaultValue: 500,
);
const int _autoRunDelayMs = int.fromEnvironment(
  'AUTO_RUN_DELAY_MS',
  defaultValue: 700,
);
const String _customStyleJson = String.fromEnvironment(
  'CUSTOM_STYLE_JSON',
  defaultValue: '',
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
  final List<String> _startupMessages = <String>[];

  late final List<ShowcaseVisualStyle> _styles = _buildStyles();
  late final JsonRegistry _registry = _buildRegistry();
  late final List<ShowcaseCase> _cases = _buildCases();

  late ShowcaseVisualStyle _selectedStyle = _findStyle(_initialStylePresetId);
  late ShowcaseCase _selectedCase = _findCase(_initialScenarioId);
  late JsonRenderSpec _activeSpec = _selectedCase.spec;

  final JsonSpecStreamCompiler _streamCompiler = JsonSpecStreamCompiler();

  Map<String, dynamic> _latestState = <String, dynamic>{};
  final List<String> _eventLog = <String>[];
  bool _isStreaming = false;

  JsonCatalog get _catalog => _buildCatalog();

  @override
  void initState() {
    super.initState();
    _latestState = _activeSpec.state;
    _eventLog
      ..add('[system] Scenario: ${_selectedCase.id}')
      ..add('[system] Style: ${_selectedStyle.id}')
      ..addAll(_startupMessages);

    if (_autoRunStream && _selectedCase.streamLines.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(
          Duration(milliseconds: _autoRunDelayMs < 0 ? 0 : _autoRunDelayMs),
          () {
            if (!mounted || _isStreaming) {
              return;
            }
            _runStreamSimulation();
          },
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_captureMode) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'flutter_json_render Showcase',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _selectedStyle.seedColor,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(body: _buildPreviewPanel()),
      );
    }

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
              OutlinedButton.icon(
                onPressed: _showAddCustomStyleDialog,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Add Custom Style'),
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

    final delayMs = _streamStepDelayMs < 16 ? 16 : _streamStepDelayMs;
    for (final line in _selectedCase.streamLines) {
      if (!mounted) return;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
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

  Future<void> _showAddCustomStyleDialog() async {
    final controller = TextEditingController(text: _customStyleTemplate());
    final theme = Theme.of(context);

    final raw = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Style'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              minLines: 12,
              maxLines: 24,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste style JSON',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (raw == null) {
      return;
    }

    try {
      final created = _parseCustomStyle(raw);
      setState(() {
        final existing = _styles.indexWhere((entry) => entry.id == created.id);
        if (existing >= 0) {
          _styles[existing] = created;
        } else {
          _styles.add(created);
        }
        _selectedStyle = created;
        _eventLog.add('[style] Applied custom style "${created.id}".');
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid style JSON: ${error.message}'),
          backgroundColor: theme.colorScheme.errorContainer,
        ),
      );
    }
  }

  ShowcaseCase _findCase(String caseId) {
    for (final value in _cases) {
      if (value.id == caseId) {
        return value;
      }
    }
    return _cases.first;
  }

  ShowcaseVisualStyle _findStyle(String styleId) {
    for (final style in _styles) {
      if (style.id == styleId) {
        return style;
      }
    }
    return _styles.first;
  }

  List<ShowcaseVisualStyle> _buildStyles() {
    final styles = List<ShowcaseVisualStyle>.of(kShowcaseStyles);
    if (_customStyleJson.trim().isEmpty) {
      return styles;
    }

    try {
      final custom = _parseCustomStyle(_customStyleJson, knownStyles: styles);
      final existing = styles.indexWhere((entry) => entry.id == custom.id);
      if (existing >= 0) {
        styles[existing] = custom;
      } else {
        styles.add(custom);
      }
      _startupMessages.add(
        '[style] Loaded custom style from CUSTOM_STYLE_JSON: ${custom.id}',
      );
    } on FormatException catch (error) {
      _startupMessages.add('[style][error] ${error.message}');
    } catch (error) {
      _startupMessages.add(
        '[style][error] Failed to parse CUSTOM_STYLE_JSON: $error',
      );
    }
    return styles;
  }

  ShowcaseVisualStyle _parseCustomStyle(
    String raw, {
    List<ShowcaseVisualStyle>? knownStyles,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Value must be valid JSON.');
    }

    if (decoded is! Map) {
      throw const FormatException('Custom style JSON must be an object.');
    }

    final map = Map<String, dynamic>.from(decoded);
    final id = map['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Field "id" is required.');
    }

    final baseId = map['base']?.toString().trim();
    final baseStyle = _resolveBaseStyle(baseId, knownStyles: knownStyles);

    final styleDefinition = JsonStyleDefinition.fromJson(map);
    return ShowcaseVisualStyle.fromDefinition(
      id: id,
      base: baseStyle,
      style: styleDefinition,
    );
  }

  ShowcaseVisualStyle _resolveBaseStyle(
    String? baseId, {
    List<ShowcaseVisualStyle>? knownStyles,
  }) {
    final basePool = knownStyles ?? _styles;
    if (baseId == null || baseId.isEmpty) {
      return kShowcaseStyles.first;
    }
    for (final style in basePool) {
      if (style.id == baseId) {
        return style;
      }
    }
    for (final style in kShowcaseStyles) {
      if (style.id == baseId) {
        return style;
      }
    }
    throw FormatException('Unknown base style "$baseId".');
  }

  String _customStyleTemplate() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'id': 'aurora',
      'base': 'midnight',
      'displayName': 'Aurora',
      'description': 'Deep blue surface with bright cyan accents.',
      'guidance': 'Use high contrast and cool accent colors.',
      'tokens': <String, dynamic>{
        'seedColor': '#0EA5E9',
        'previewBackground': '#020B1A',
        'panelBackground': '#0B1220',
        'panelBorder': '#123047',
        'textPrimary': '#E0F2FE',
        'accent': '#22D3EE',
        'trackBackground': '#17314A',
        'neutralChip': <String, dynamic>{
          'background': '#102338',
          'border': '#1E3A5F',
          'foreground': '#D6EFFF',
        },
        'successChip': <String, dynamic>{
          'background': '#063B2E',
          'border': '#0F766E',
          'foreground': '#99F6E4',
        },
        'warningChip': <String, dynamic>{
          'background': '#4A2E05',
          'border': '#A16207',
          'foreground': '#FDE68A',
        },
        'dangerChip': <String, dynamic>{
          'background': '#4A0D1B',
          'border': '#BE123C',
          'foreground': '#FECDD3',
        },
      },
    });
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
        for (final style in _styles) style.id: style.toStyleDefinition(),
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
      ShowcaseCase(
        id: 'chat_stream',
        title: '6) Chat Stream Build-Up',
        description:
            'Mimics LLM output chunks that progressively build a chat-like UI.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'chatPanel',
          'state': <String, dynamic>{'phase': 'starting'},
          'elements': <String, dynamic>{
            'chatPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'LLM Chat Stream'},
              'children': <String>['statusChip', 'messages'],
            },
            'statusChip': <String, dynamic>{
              'type': 'StatusChip',
              'props': <String, dynamic>{
                'label': <String, dynamic>{r'$state': '/phase'},
                'variant': 'warning',
              },
            },
            'messages': <String, dynamic>{
              'type': 'Column',
              'props': <String, dynamic>{'spacing': 8},
              'children': <String>['assistantIntro'],
            },
            'assistantIntro': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': 'assistant: waiting for first token...',
                'fontSize': 16,
                'fontWeight': '600',
              },
            },
          },
        }),
        streamLines: <String>[
          '{"op":"replace","path":"/state/phase","value":"receiving intent"}',
          '{"op":"add","path":"/elements/userMsg","value":{"type":"Text","props":{"text":"user: Build a compact analytics card with trend and status.","fontSize":16}}}',
          '{"op":"add","path":"/elements/messages/children/1","value":"userMsg"}',
          '{"op":"replace","path":"/state/phase","value":"generating layout"}',
          '{"op":"add","path":"/elements/assistantMsg","value":{"type":"Text","props":{"text":"assistant: Added title, KPI value, and trend indicator.","fontSize":16,"fontWeight":"600"}}}',
          '{"op":"add","path":"/elements/messages/children/2","value":"assistantMsg"}',
          '{"op":"replace","path":"/state/phase","value":"applying patch"}',
          '{"op":"add","path":"/elements/assistantDone","value":{"type":"StatusChip","props":{"label":"render-ready","variant":"success"}}}',
          '{"op":"add","path":"/elements/messages/children/3","value":"assistantDone"}',
          '{"op":"replace","path":"/elements/statusChip/props/variant","value":"success"}',
          '{"op":"replace","path":"/state/phase","value":"complete"}',
        ],
      ),
      ShowcaseCase(
        id: 'component_stream',
        title: '7) Streamed Component Mix',
        description:
            'Streams patches that progressively render many component types.',
        spec: JsonRenderSpec.fromJson(<String, dynamic>{
          'root': 'mixPanel',
          'state': <String, dynamic>{
            'status': 'booting',
            'progress': 0.12,
            'showCta': false,
          },
          'elements': <String, dynamic>{
            'mixPanel': <String, dynamic>{
              'type': 'Panel',
              'props': <String, dynamic>{'title': 'Component Stream'},
              'children': <String>['statusRow', 'stack'],
            },
            'statusRow': <String, dynamic>{
              'type': 'Row',
              'props': <String, dynamic>{'spacing': 8},
              'children': <String>['statusLabel', 'statusChip'],
            },
            'statusLabel': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{'text': 'Status'},
            },
            'statusChip': <String, dynamic>{
              'type': 'StatusChip',
              'props': <String, dynamic>{
                'label': <String, dynamic>{r'$state': '/status'},
                'variant': 'warning',
              },
            },
            'stack': <String, dynamic>{
              'type': 'Column',
              'props': <String, dynamic>{'spacing': 10},
              'children': <String>['progressLabel', 'progressBar'],
            },
            'progressLabel': <String, dynamic>{
              'type': 'Text',
              'props': <String, dynamic>{
                'text': 'Progress',
                'fontSize': 15,
                'fontWeight': '600',
              },
            },
            'progressBar': <String, dynamic>{
              'type': 'ProgressBar',
              'props': <String, dynamic>{
                'value': <String, dynamic>{r'$state': '/progress'},
              },
            },
          },
        }),
        streamLines: <String>[
          '{"op":"replace","path":"/state/status","value":"receiving schema"}',
          '{"op":"add","path":"/elements/heroCard","value":{"type":"Container","props":{"padding":12,"radius":12,"borderColor":"#FDBA74","borderWidth":1,"color":"#FFF7ED"},"children":["heroTitle","heroBody"]}}',
          '{"op":"add","path":"/elements/heroTitle","value":{"type":"Text","props":{"text":"Quarterly Snapshot","fontSize":17,"fontWeight":"700"}}}',
          '{"op":"add","path":"/elements/heroBody","value":{"type":"Text","props":{"text":"Revenue +12.4%, churn down 1.3pt.","fontSize":14}}}',
          '{"op":"add","path":"/elements/stack/children/2","value":"heroCard"}',
          '{"op":"replace","path":"/state/progress","value":0.38}',
          '{"op":"add","path":"/elements/gapA","value":{"type":"SizedBox","props":{"height":6}}}',
          '{"op":"add","path":"/elements/stack/children/3","value":"gapA"}',
          '{"op":"add","path":"/elements/metricsRow","value":{"type":"Row","props":{"spacing":8,"runSpacing":8,"overflow":"wrap"},"children":["metricA","metricB","metricC"]}}',
          '{"op":"add","path":"/elements/metricA","value":{"type":"Container","props":{"padding":10,"radius":10,"borderColor":"#FDBA74","borderWidth":1},"children":["metricAText"]}}',
          '{"op":"add","path":"/elements/metricAText","value":{"type":"Text","props":{"text":"Sessions 18.2k"}}}',
          '{"op":"add","path":"/elements/metricB","value":{"type":"Container","props":{"padding":10,"radius":10,"borderColor":"#FDBA74","borderWidth":1},"children":["metricBText"]}}',
          '{"op":"add","path":"/elements/metricBText","value":{"type":"Text","props":{"text":"Conversion 6.8%"}}}',
          '{"op":"add","path":"/elements/metricC","value":{"type":"Container","props":{"padding":10,"radius":10,"borderColor":"#FDBA74","borderWidth":1},"children":["metricCText"]}}',
          '{"op":"add","path":"/elements/metricCText","value":{"type":"Text","props":{"text":"AOV \$84"}}}',
          '{"op":"add","path":"/elements/stack/children/4","value":"metricsRow"}',
          '{"op":"replace","path":"/state/progress","value":0.74}',
          '{"op":"add","path":"/elements/buttonCenter","value":{"type":"Center","visible":{"\$state":"/showCta","eq":true},"children":["publishBtn"]}}',
          '{"op":"add","path":"/elements/publishBtn","value":{"type":"Button","props":{"label":"Publish Snapshot"}}}',
          '{"op":"add","path":"/elements/stack/children/5","value":"buttonCenter"}',
          '{"op":"replace","path":"/state/showCta","value":true}',
          '{"op":"replace","path":"/state/progress","value":1}',
          '{"op":"replace","path":"/elements/statusChip/props/variant","value":"success"}',
          '{"op":"replace","path":"/state/status","value":"complete"}',
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

  ShowcaseChipStyle copyWith({
    Color? background,
    Color? border,
    Color? foreground,
  }) {
    return ShowcaseChipStyle(
      background: background ?? this.background,
      border: border ?? this.border,
      foreground: foreground ?? this.foreground,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'background': _hexOf(background),
      'border': _hexOf(border),
      'foreground': _hexOf(foreground),
    };
  }
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

  factory ShowcaseVisualStyle.fromDefinition({
    required String id,
    required ShowcaseVisualStyle base,
    required JsonStyleDefinition style,
  }) {
    final tokens = style.tokens;
    return base.copyWith(
      id: id,
      name: style.displayName.trim().isEmpty ? id : style.displayName.trim(),
      description: style.description.trim().isEmpty
          ? base.description
          : style.description.trim(),
      promptGuidance: style.guidance.trim().isEmpty
          ? base.promptGuidance
          : style.guidance.trim(),
      seedColor: _safeColor(tokens['seedColor']?.toString()) ?? base.seedColor,
      previewBackground:
          _safeColor(tokens['previewBackground']?.toString()) ??
          base.previewBackground,
      panelBackground:
          _safeColor(tokens['panelBackground']?.toString()) ??
          base.panelBackground,
      panelBorder:
          _safeColor(tokens['panelBorder']?.toString()) ?? base.panelBorder,
      textPrimary:
          _safeColor(tokens['textPrimary']?.toString()) ?? base.textPrimary,
      accent: _safeColor(tokens['accent']?.toString()) ?? base.accent,
      trackBackground:
          _safeColor(tokens['trackBackground']?.toString()) ??
          base.trackBackground,
      neutralChip: _mergeChip(base.neutralChip, tokens['neutralChip']),
      successChip: _mergeChip(base.successChip, tokens['successChip']),
      warningChip: _mergeChip(base.warningChip, tokens['warningChip']),
      dangerChip: _mergeChip(base.dangerChip, tokens['dangerChip']),
    );
  }

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

  ShowcaseVisualStyle copyWith({
    String? id,
    String? name,
    String? description,
    String? promptGuidance,
    Color? seedColor,
    Color? previewBackground,
    Color? panelBackground,
    Color? panelBorder,
    Color? textPrimary,
    Color? accent,
    Color? trackBackground,
    ShowcaseChipStyle? neutralChip,
    ShowcaseChipStyle? successChip,
    ShowcaseChipStyle? warningChip,
    ShowcaseChipStyle? dangerChip,
  }) {
    return ShowcaseVisualStyle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      promptGuidance: promptGuidance ?? this.promptGuidance,
      seedColor: seedColor ?? this.seedColor,
      previewBackground: previewBackground ?? this.previewBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      panelBorder: panelBorder ?? this.panelBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      accent: accent ?? this.accent,
      trackBackground: trackBackground ?? this.trackBackground,
      neutralChip: neutralChip ?? this.neutralChip,
      successChip: successChip ?? this.successChip,
      warningChip: warningChip ?? this.warningChip,
      dangerChip: dangerChip ?? this.dangerChip,
    );
  }

  JsonStyleDefinition toStyleDefinition() {
    return JsonStyleDefinition(
      displayName: name,
      description: description,
      guidance: promptGuidance,
      tokens: <String, dynamic>{
        'seedColor': _hexOf(seedColor),
        'previewBackground': _hexOf(previewBackground),
        'panelBackground': _hexOf(panelBackground),
        'panelBorder': _hexOf(panelBorder),
        'textPrimary': _hexOf(textPrimary),
        'accent': _hexOf(accent),
        'trackBackground': _hexOf(trackBackground),
        'neutralChip': neutralChip.toJson(),
        'successChip': successChip.toJson(),
        'warningChip': warningChip.toJson(),
        'dangerChip': dangerChip.toJson(),
      },
    );
  }
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

ShowcaseChipStyle _mergeChip(ShowcaseChipStyle base, dynamic raw) {
  if (raw is! Map) {
    return base;
  }
  final map = Map<String, dynamic>.from(raw);
  return base.copyWith(
    background: _safeColor(map['background']?.toString()) ?? base.background,
    border: _safeColor(map['border']?.toString()) ?? base.border,
    foreground: _safeColor(map['foreground']?.toString()) ?? base.foreground,
  );
}

String _hexOf(Color color) {
  // ignore: deprecated_member_use
  final hex = color.value.toRadixString(16).toUpperCase().padLeft(8, '0');
  return '#${hex.substring(2)}';
}
