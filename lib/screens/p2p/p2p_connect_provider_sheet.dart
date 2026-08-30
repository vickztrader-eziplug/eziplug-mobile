import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/p2p_service.dart';

/// Bottom sheet that renders a credential form purely from
/// [P2pProvider.authSchema] and calls the exchange/bank connect endpoint.
///
/// Never hardcode field names here — every input is derived from the
/// provider's dynamic schema so any exchange/bank the backend adds later
/// works without an app update.
Future<bool?> showP2pConnectProviderSheet(
  BuildContext context, {
  required P2pProvider provider,
  required P2pService service,
  required String category, // "exchange" | "bank"
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _P2pConnectProviderSheet(
      provider: provider,
      service: service,
      category: category,
    ),
  );
}

class _P2pConnectProviderSheet extends StatefulWidget {
  final P2pProvider provider;
  final P2pService service;
  final String category;

  const _P2pConnectProviderSheet({
    required this.provider,
    required this.service,
    required this.category,
  });

  @override
  State<_P2pConnectProviderSheet> createState() => _P2pConnectProviderSheetState();
}

class _P2pConnectProviderSheetState extends State<_P2pConnectProviderSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectValues = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.provider.authSchema) {
      if (field.type == 'select') {
        _selectValues[field.name] = field.options?.isNotEmpty == true
            ? field.options!.first
            : null;
      } else {
        _controllers[field.name] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final credentials = <String, dynamic>{};
    for (final field in widget.provider.authSchema) {
      if (field.type == 'select') {
        credentials[field.name] = _selectValues[field.name];
      } else {
        credentials[field.name] = _controllers[field.name]?.text.trim();
      }
    }

    setState(() => _isSubmitting = true);
    final result = widget.category == 'exchange'
        ? await widget.service.connectExchange(
            providerId: widget.provider.id,
            credentials: credentials,
          )
        : await widget.service.connectBank(
            providerId: widget.provider.id,
            credentials: credentials,
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      ToastHelper.showSuccess(
        result['message']?.toString() ?? 'Connected successfully',
      );
      Navigator.of(context).pop(true);
    } else {
      ToastHelper.showError(
        result['message']?.toString() ?? 'Failed to connect ${widget.provider.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    final hasLogo = widget.provider.logoUrl != null && widget.provider.logoUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: hasLogo
                              ? null
                              : LinearGradient(
                                  colors: [accent, accent.withOpacity(0.7)],
                                ),
                          color: hasLogo ? Colors.white : null,
                          border: hasLogo ? Border.all(color: Colors.grey.shade200) : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasLogo
                            ? Padding(
                                padding: const EdgeInsets.all(5),
                                child: Image.network(
                                  widget.provider.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(Icons.link_rounded, color: accent),
                                ),
                              )
                            : Center(
                                child: Text(
                                  widget.provider.name.isNotEmpty
                                      ? widget.provider.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Connect ${widget.provider.name}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  if (widget.provider.connectInstruction != null &&
                      widget.provider.connectInstruction!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withOpacity(0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.provider.connectInstruction!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (widget.provider.authSchema.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No credentials required for this provider.'),
                    )
                  else
                    ...widget.provider.authSchema.map(_buildField),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Your credentials are encrypted before being stored.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _submit,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.75)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.link_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Connect',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
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

  Widget _buildField(P2pAuthSchemaField field) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    final fillColor = isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50;
    final isPassword = field.type == 'password';
    final prefixIcon = switch (field.type) {
      'password' => Icons.lock_outline_rounded,
      'email' => Icons.alternate_email_rounded,
      'date' => Icons.calendar_today_outlined,
      'select' => Icons.list_alt_rounded,
      _ => Icons.badge_outlined,
    };
    final baseDecoration = InputDecoration(
      labelText: field.label,
      prefixIcon: Icon(prefixIcon, size: 19),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: field.type == 'select'
          ? DropdownButtonFormField<String>(
              initialValue: _selectValues[field.name],
              decoration: baseDecoration,
              items: (field.options ?? [])
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _selectValues[field.name] = v),
              validator: (v) {
                if (field.required && (v == null || v.isEmpty)) {
                  return '${field.label} is required';
                }
                return null;
              },
            )
          : TextFormField(
              controller: _controllers[field.name],
              obscureText: isPassword,
              decoration: baseDecoration,
              validator: (v) {
                if (field.required && (v == null || v.trim().isEmpty)) {
                  return '${field.label} is required';
                }
                return null;
              },
            ),
    );
  }
}
