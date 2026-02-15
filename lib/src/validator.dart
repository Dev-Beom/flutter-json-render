import 'catalog.dart';
import 'spec.dart';

enum JsonSpecIssueSeverity { warning, error }

class JsonSpecIssue {
  const JsonSpecIssue({
    required this.message,
    required this.severity,
    this.elementKey,
  });

  final String message;
  final JsonSpecIssueSeverity severity;
  final String? elementKey;
}

class JsonSpecValidationResult {
  const JsonSpecValidationResult(this.issues);

  final List<JsonSpecIssue> issues;

  bool get isValid =>
      !issues.any((issue) => issue.severity == JsonSpecIssueSeverity.error);
}

JsonSpecValidationResult validateSpec(
  JsonRenderSpec spec, {
  JsonCatalog? catalog,
  bool strictCatalog = false,
}) {
  final issues = <JsonSpecIssue>[];

  if (spec.root.isEmpty) {
    issues.add(
      const JsonSpecIssue(
        message: 'Spec root is empty.',
        severity: JsonSpecIssueSeverity.error,
      ),
    );
  }

  if (!spec.elements.containsKey(spec.root)) {
    issues.add(
      JsonSpecIssue(
        message: 'Root "${spec.root}" does not exist in elements.',
        severity: JsonSpecIssueSeverity.error,
      ),
    );
  }

  if (catalog != null && spec.style != null && spec.style!.isNotEmpty) {
    if (!catalog.hasStyle(spec.style!)) {
      issues.add(
        JsonSpecIssue(
          message: 'Spec references unknown style "${spec.style}".',
          severity: strictCatalog
              ? JsonSpecIssueSeverity.error
              : JsonSpecIssueSeverity.warning,
        ),
      );
    }
  }

  for (final entry in spec.elements.entries) {
    final key = entry.key;
    final element = entry.value;

    if (element.type.isEmpty) {
      issues.add(
        JsonSpecIssue(
          message: 'Element "$key" has an empty type.',
          severity: JsonSpecIssueSeverity.error,
          elementKey: key,
        ),
      );
    }

    for (final childKey in element.children) {
      if (!spec.elements.containsKey(childKey)) {
        issues.add(
          JsonSpecIssue(
            message: 'Element "$key" references missing child "$childKey".',
            severity: JsonSpecIssueSeverity.error,
            elementKey: key,
          ),
        );
      }
    }

    final repeat = element.repeat;
    if (repeat != null && repeat.statePath.isEmpty) {
      issues.add(
        JsonSpecIssue(
          message: 'Element "$key" repeat.statePath is empty.',
          severity: JsonSpecIssueSeverity.error,
          elementKey: key,
        ),
      );
    }

    if (catalog == null) continue;

    final hasComponent = catalog.hasComponent(element.type);
    if (!hasComponent) {
      issues.add(
        JsonSpecIssue(
          message:
              'Element "$key" uses unknown component type "${element.type}".',
          severity: strictCatalog
              ? JsonSpecIssueSeverity.error
              : JsonSpecIssueSeverity.warning,
          elementKey: key,
        ),
      );
    }

    for (final eventBindings in element.on.values) {
      for (final binding in eventBindings) {
        if (!catalog.hasAction(binding.action)) {
          issues.add(
            JsonSpecIssue(
              message:
                  'Element "$key" references unknown action "${binding.action}".',
              severity: strictCatalog
                  ? JsonSpecIssueSeverity.error
                  : JsonSpecIssueSeverity.warning,
              elementKey: key,
            ),
          );
        }
      }
    }
  }

  return JsonSpecValidationResult(issues);
}
