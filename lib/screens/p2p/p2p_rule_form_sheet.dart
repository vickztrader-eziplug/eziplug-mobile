import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/p2p_service.dart';

/// Bottom sheet for creating/editing a [P2pRule]. Renders a rule-type-aware
/// set of condition fields — the shape of `conditions` differs per [P2pRule]
/// type, so this form switches on the selected type to build the right
/// small form, per the backend contract.
Future<bool?> showP2pRuleFormSheet(
  BuildContext context, {
  required P2pService service,
  P2pRule? existingRule,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _P2pRuleFormSheet(service: service, existingRule: existingRule),
  );
}

class _P2pRuleFormSheet extends StatefulWidget {
  final P2pService service;
  final P2pRule? existingRule;

  const _P2pRuleFormSheet({required this.service, this.existingRule});

  @override
  State<_P2pRuleFormSheet> createState() => _P2pRuleFormSheetState();
}

class _P2pRuleFormSheetState extends State<_P2pRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priorityController = TextEditingController(text: '0');

  late String _type;
  late String _action;
  bool _isActive = true;
  bool _isSubmitting = false;

  // Condition field controllers, keyed by condition field name.
  final Map<String, TextEditingController> _conditionControllers = {};
  String _amountOperator = '>';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRule;
    _type = existing?.type ?? P2pRule.typeAmountLimit;
    _action = existing?.action ?? P2pRule.actionManualReview;
    _isActive = existing?.isActive ?? true;
    if (existing != null) {
      _nameController.text = existing.name;
      _priorityController.text = existing.priority.toString();
      final conditions = existing.conditions;
      if (existing.type == P2pRule.typeAmountLimit) {
        _amountOperator = conditions['operator']?.toString() ?? '>';
      }
      for (final entry in conditions.entries) {
        if (entry.key == 'operator') continue;
        if (entry.key == 'banks' && entry.value is List) {
          _conditionControllers['banks'] =
              TextEditingController(text: (entry.value as List).join(', '));
        } else {
          _conditionControllers[entry.key] =
              TextEditingController(text: entry.value?.toString() ?? '');
        }
      }
    }
    _ensureControllersForType(_type);
  }

  void _ensureControllersForType(String type) {
    for (final field in _fieldsForType(type)) {
      _conditionControllers.putIfAbsent(field, () => TextEditingController());
    }
  }

  List<String> _fieldsForType(String type) {
    switch (type) {
      case P2pRule.typeAmountLimit:
        return ['value'];
      case P2pRule.typeDailyLimit:
        return ['limit'];
      case P2pRule.typeMaxBadReviews:
      case P2pRule.typeMaxAvgReleaseTime:
      case P2pRule.typeAutoMarkPayTime:
        return ['max'];
      case P2pRule.typeWorkingHours:
        return ['start', 'end', 'timezone'];
      case P2pRule.typeAllowedBanks:
        return ['banks'];
      case P2pRule.typeManualThreshold:
        return ['threshold'];
      case P2pRule.typeNewUserDelay:
        return ['delay_minutes'];
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priorityController.dispose();
    for (final c in _conditionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildConditions() {
    switch (_type) {
      case P2pRule.typeAmountLimit:
        return {
          'operator': _amountOperator,
          'value': num.tryParse(_conditionControllers['value']?.text ?? '') ?? 0,
        };
      case P2pRule.typeDailyLimit:
        return {'limit': num.tryParse(_conditionControllers['limit']?.text ?? '') ?? 0};
      case P2pRule.typeMaxBadReviews:
      case P2pRule.typeMaxAvgReleaseTime:
      case P2pRule.typeAutoMarkPayTime:
        return {'max': num.tryParse(_conditionControllers['max']?.text ?? '') ?? 0};
      case P2pRule.typeWorkingHours:
        return {
          'start': _conditionControllers['start']?.text.trim() ?? '',
          'end': _conditionControllers['end']?.text.trim() ?? '',
          'timezone': _conditionControllers['timezone']?.text.trim() ?? '',
        };
      case P2pRule.typeAllowedBanks:
        final raw = _conditionControllers['banks']?.text ?? '';
        return {
          'banks': raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        };
      case P2pRule.typeManualThreshold:
        return {
          'threshold': num.tryParse(_conditionControllers['threshold']?.text ?? '') ?? 0,
        };
      case P2pRule.typeNewUserDelay:
        return {
          'delay_minutes':
              num.tryParse(_conditionControllers['delay_minutes']?.text ?? '') ?? 0,
        };
      default:
        return {};
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final conditions = _buildConditions();
    final priority = int.tryParse(_priorityController.text.trim()) ?? 0;

    final result = widget.existingRule == null
        ? await widget.service.createRule(
            name: _nameController.text.trim(),
            type: _type,
            conditions: conditions,
            action: _action,
            priority: priority,
            isActive: _isActive,
          )
        : await widget.service.updateRule(
            widget.existingRule!.id,
            name: _nameController.text.trim(),
            type: _type,
            conditions: conditions,
            action: _action,
            priority: priority,
            isActive: _isActive,
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      ToastHelper.showSuccess(
        result['message']?.toString() ??
            (widget.existingRule == null ? 'Rule created' : 'Rule updated'),
      );
      Navigator.of(context).pop(true);
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to save rule');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.existingRule == null ? 'New Rule' : 'Edit Rule',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Rule Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: P2pRule.allTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(P2pRule.typeLabel(t)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
                        _ensureControllersForType(v);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ..._buildConditionFields(),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _action,
                    decoration: const InputDecoration(labelText: 'Action'),
                    items: P2pRule.allActions
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) => setState(() => _action = v ?? _action),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priorityController,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || int.tryParse(v.trim()) == null) ? 'Enter a number' : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    activeThumbColor: accent,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConditionFields() {
    switch (_type) {
      case P2pRule.typeAmountLimit:
        return [
          DropdownButtonFormField<String>(
            initialValue: _amountOperator,
            decoration: const InputDecoration(labelText: 'Operator'),
            items: const ['>', '>=', '<', '<=']
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _amountOperator = v ?? _amountOperator),
          ),
          const SizedBox(height: 14),
          _numberField('value', 'Amount Value'),
        ];
      case P2pRule.typeDailyLimit:
        return [_numberField('limit', 'Daily Limit')];
      case P2pRule.typeMaxBadReviews:
        return [_numberField('max', 'Max Bad Reviews')];
      case P2pRule.typeMaxAvgReleaseTime:
        return [_numberField('max', 'Max Avg Release Time (seconds)')];
      case P2pRule.typeAutoMarkPayTime:
        return [_numberField('max', 'Auto Mark-Pay Time (seconds)')];
      case P2pRule.typeWorkingHours:
        return [
          _textField('start', 'Start Time (HH:mm)'),
          const SizedBox(height: 14),
          _textField('end', 'End Time (HH:mm)'),
          const SizedBox(height: 14),
          _textField('timezone', 'Timezone (e.g. Africa/Lagos)'),
        ];
      case P2pRule.typeAllowedBanks:
        return [_textField('banks', 'Allowed Banks (comma-separated)')];
      case P2pRule.typeManualThreshold:
        return [_numberField('threshold', 'Manual Review Threshold')];
      case P2pRule.typeNewUserDelay:
        return [_numberField('delay_minutes', 'New User Delay (minutes)')];
      default:
        return [];
    }
  }

  Widget _numberField(String key, String label) {
    return TextFormField(
      controller: _conditionControllers[key],
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _textField(String key, String label) {
    return TextFormField(
      controller: _conditionControllers[key],
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}
