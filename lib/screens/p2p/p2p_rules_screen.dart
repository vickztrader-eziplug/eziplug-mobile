import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../models/p2p/p2p.dart';
import '../../services/auth_service.dart';
import '../../services/p2p_service.dart';
import 'p2p_rule_form_sheet.dart';

/// Automation rules screen, with Blacklist/Whitelist reachable via
/// additional tabs on the same screen (kept simple per spec, rather than a
/// separate route).
class P2pRulesScreen extends StatefulWidget {
  const P2pRulesScreen({super.key});

  @override
  State<P2pRulesScreen> createState() => _P2pRulesScreenState();
}

class _P2pRulesScreenState extends State<P2pRulesScreen> {
  late final P2pService _service;

  @override
  void initState() {
    super.initState();
    _service = P2pService(
      authService: Provider.of<AuthService>(context, listen: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rules & Lists'),
          backgroundColor: isDark ? AppColors.headerDark : AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Rules'),
              Tab(text: 'Blacklist'),
              Tab(text: 'Whitelist'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RulesTab(service: _service),
            _ListTab(service: _service, listType: 'blacklist'),
            _ListTab(service: _service, listType: 'whitelist'),
          ],
        ),
      ),
    );
  }
}

class _RulesTab extends StatefulWidget {
  final P2pService service;

  const _RulesTab({required this.service});

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<P2pRule> _rules = [];
  final Set<String> _busyIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await widget.service.getRules();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _rules = (result['rules'] as List<P2pRule>?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load rules';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(P2pRule rule, bool value) async {
    setState(() => _busyIds.add(rule.id));
    final result = await widget.service.updateRule(rule.id, isActive: value);
    if (!mounted) return;
    setState(() => _busyIds.remove(rule.id));
    if (result['success'] == true) {
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to update rule');
    }
  }

  Future<void> _delete(P2pRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Delete "${rule.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(rule.id));
    final result = await widget.service.deleteRule(rule.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(rule.id));
    if (result['success'] == true) {
      ToastHelper.showSuccess('Rule deleted');
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to delete rule');
    }
  }

  Future<void> _openForm({P2pRule? existingRule}) async {
    final saved = await showP2pRuleFormSheet(
      context,
      service: widget.service,
      existingRule: existingRule,
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_rules.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: const Center(child: Text('No rules yet. Tap + to add one.')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final rule = _rules[index];
          final isBusy = _busyIds.contains(rule.id);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${P2pRule.typeLabel(rule.type)} → ${rule.action} (priority ${rule.priority})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else ...[
                  Switch(
                    value: rule.isActive,
                    activeThumbColor: accent,
                    onChanged: (v) => _toggleActive(rule, v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _openForm(existingRule: rule),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _delete(rule),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ListTab extends StatefulWidget {
  final P2pService service;
  final String listType; // "blacklist" | "whitelist"

  const _ListTab({required this.service, required this.listType});

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _error;
  List<P2pListEntry> _entries = [];
  final Set<String> _busyIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await widget.service.getLists(widget.listType);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _entries = (result['entries'] as List<P2pListEntry>?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Failed to load ${widget.listType}';
        _isLoading = false;
      });
    }
  }

  Future<void> _delete(P2pListEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove entry?'),
        content: Text('Remove "${entry.value}" from the ${widget.listType}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(entry.id));
    final result = await widget.service.deleteListEntry(widget.listType, entry.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(entry.id));
    if (result['success'] == true) {
      ToastHelper.showSuccess('Entry removed');
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to remove entry');
    }
  }

  Future<void> _openAddDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;
    String entryType = P2pListEntry.entryTypeBankAccount;
    final valueController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add to ${widget.listType}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: entryType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: P2pListEntry.allEntryTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => entryType = v ?? entryType),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: valueController,
                    decoration: const InputDecoration(labelText: 'Value'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason (optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (added != true) return;

    final result = await widget.service.addListEntry(
      widget.listType,
      entryType: entryType,
      value: valueController.text.trim(),
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );
    if (!mounted) return;
    if (result['success'] == true) {
      ToastHelper.showSuccess('Added to ${widget.listType}');
      _load();
    } else {
      ToastHelper.showError(result['message']?.toString() ?? 'Failed to add entry');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
        onPressed: _openAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(child: Text('No ${widget.listType} entries yet.')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          final isBusy = _busyIds.contains(entry.id);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        entry.reason?.isNotEmpty == true
                            ? '${entry.entryType} • ${entry.reason}'
                            : entry.entryType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(entry),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
