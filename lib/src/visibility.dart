import 'resolver.dart';

enum _ComparisonOperator { eq, neq, gt, gte, lt, lte }

bool evaluateVisibility(dynamic rawCondition, JsonResolutionContext context) {
  if (rawCondition == null) return true;
  if (rawCondition is bool) return rawCondition;

  if (rawCondition is List) {
    return rawCondition.every((entry) => evaluateVisibility(entry, context));
  }

  if (rawCondition is! Map) {
    return isTruthy(rawCondition);
  }

  if (rawCondition.containsKey(r'$and')) {
    final list = rawCondition[r'$and'];
    if (list is! List) return false;
    return list.every((entry) => evaluateVisibility(entry, context));
  }

  if (rawCondition.containsKey(r'$or')) {
    final list = rawCondition[r'$or'];
    if (list is! List) return false;
    return list.any((entry) => evaluateVisibility(entry, context));
  }

  final source = _resolveConditionSource(rawCondition, context);
  var result = _applyOperators(rawCondition, source, context);

  if (rawCondition['not'] == true) {
    result = !result;
  }

  return result;
}

dynamic _resolveConditionSource(
  Map<dynamic, dynamic> rawCondition,
  JsonResolutionContext context,
) {
  if (rawCondition.containsKey(r'$state')) {
    return resolveValue(<String, dynamic>{
      r'$state': rawCondition[r'$state'],
    }, context);
  }
  if (rawCondition.containsKey(r'$item')) {
    return resolveValue(<String, dynamic>{
      r'$item': rawCondition[r'$item'],
    }, context);
  }
  if (rawCondition.containsKey(r'$index')) {
    return resolveValue(<String, dynamic>{
      r'$index': rawCondition[r'$index'],
    }, context);
  }
  return null;
}

bool _applyOperators(
  Map<dynamic, dynamic> rawCondition,
  dynamic source,
  JsonResolutionContext context,
) {
  final op = _firstOperator(rawCondition);
  if (op == null) {
    return isTruthy(source);
  }

  final rhsRaw = rawCondition[_operatorKey(op)];
  final rhs = resolveValue(rhsRaw, context);

  switch (op) {
    case _ComparisonOperator.eq:
      return source == rhs;
    case _ComparisonOperator.neq:
      return source != rhs;
    case _ComparisonOperator.gt:
      return _toNum(source) > _toNum(rhs);
    case _ComparisonOperator.gte:
      return _toNum(source) >= _toNum(rhs);
    case _ComparisonOperator.lt:
      return _toNum(source) < _toNum(rhs);
    case _ComparisonOperator.lte:
      return _toNum(source) <= _toNum(rhs);
  }
}

_ComparisonOperator? _firstOperator(Map<dynamic, dynamic> rawCondition) {
  if (rawCondition.containsKey('eq')) return _ComparisonOperator.eq;
  if (rawCondition.containsKey('neq')) return _ComparisonOperator.neq;
  if (rawCondition.containsKey('gt')) return _ComparisonOperator.gt;
  if (rawCondition.containsKey('gte')) return _ComparisonOperator.gte;
  if (rawCondition.containsKey('lt')) return _ComparisonOperator.lt;
  if (rawCondition.containsKey('lte')) return _ComparisonOperator.lte;
  return null;
}

String _operatorKey(_ComparisonOperator op) {
  switch (op) {
    case _ComparisonOperator.eq:
      return 'eq';
    case _ComparisonOperator.neq:
      return 'neq';
    case _ComparisonOperator.gt:
      return 'gt';
    case _ComparisonOperator.gte:
      return 'gte';
    case _ComparisonOperator.lt:
      return 'lt';
    case _ComparisonOperator.lte:
      return 'lte';
  }
}

double _toNum(dynamic value) {
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value?.toString() ?? '');
  return parsed ?? double.nan;
}
