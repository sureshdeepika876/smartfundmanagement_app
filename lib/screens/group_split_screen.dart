import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/settlement_optimizer.dart';

class _GroupExpenseEntry {
  String payer;
  double amount;
  String description;
  _GroupExpenseEntry({required this.payer, required this.amount, required this.description});
}

/// Group expense splitting with "minimum transaction" settlement —
/// like Splitwise, but computes the fewest transfers needed to settle
/// everyone's debts instead of everyone paying everyone.
class GroupSplitScreen extends StatefulWidget {
  const GroupSplitScreen({super.key});
  @override
  State<GroupSplitScreen> createState() => _GroupSplitScreenState();
}

class _GroupSplitScreenState extends State<GroupSplitScreen> {
  final List<String> _members = [];
  final List<_GroupExpenseEntry> _expenses = [];
  final _memberCtrl = TextEditingController();
  List<Transaction>? _settlement;
  bool _computing = false;

  @override
  void dispose() {
    _memberCtrl.dispose();
    super.dispose();
  }

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty || _members.contains(name)) return;
    setState(() {
      _members.add(name);
      _memberCtrl.clear();
    });
  }

  void _addExpenseDialog() {
    if (_members.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least 2 members first')));
      return;
    }
    String payer = _members.first;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Group Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: payer,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: _members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setStateDialog(() => payer = v!),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (e.g. Dinner)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt > 0) {
                  setState(() {
                    _expenses.add(_GroupExpenseEntry(
                        payer: payer, amount: amt, description: descCtrl.text.isEmpty ? 'Expense' : descCtrl.text));
                    _settlement = null; // invalidate previous settlement
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  /// Splits every group expense equally among all members, computes each
  /// member's net balance (paid - fair share), then finds the minimum set
  /// of transactions needed to settle up.
  Map<String, double> _computeNetBalances() {
    final balances = {for (final m in _members) m: 0.0};
    final totalSpent = _expenses.fold(0.0, (s, e) => s + e.amount);
    final fairShare = _members.isEmpty ? 0.0 : totalSpent / _members.length;

    for (final e in _expenses) {
      balances[e.payer] = (balances[e.payer] ?? 0) + e.amount;
    }
    for (final m in _members) {
      balances[m] = (balances[m] ?? 0) - fairShare;
    }
    return balances;
  }

  Future<void> _settleUp() async {
    setState(() => _computing = true);
    final balances = _computeNetBalances();
    try {
      // Try backend for consistency with server-side algorithm (same logic,
      // but demonstrates the full-stack integration).
      final api = ApiService(context.read<AuthService>());
      final result = await api.optimizeSettlement(balances);
      final txns = (result['transactions'] as List)
          .map((t) => Transaction(t['from'], t['to'], (t['amount'] as num).toDouble()))
          .toList();
      setState(() => _settlement = txns);
    } catch (_) {
      // Backend unreachable — use the identical algorithm on-device.
      setState(() => _settlement = SettlementOptimizer.optimize(balances));
    }
    setState(() => _computing = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = _expenses.fold(0.0, (s, e) => s + e.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Group Expense Split')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1. Add Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _memberCtrl,
                  decoration: const InputDecoration(hintText: 'Member name', border: OutlineInputBorder()),
                  onSubmitted: (_) => _addMember(),
                ),
              ),
              IconButton.filled(onPressed: _addMember, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _members
                .map((m) => Chip(
                      label: Text(m),
                      onDeleted: () => setState(() {
                        _members.remove(m);
                        _expenses.removeWhere((e) => e.payer == m);
                        _settlement = null;
                      }),
                    ))
                .toList(),
          ),
          const Divider(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('2. Group Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(onPressed: _addExpenseDialog, icon: const Icon(Icons.add), label: const Text('Add')),
            ],
          ),
          if (_expenses.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No expenses added yet.'))
          else
            ..._expenses.map((e) => ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(e.description),
                  subtitle: Text('Paid by ${e.payer}'),
                  trailing: Text('₹${e.amount.toStringAsFixed(2)}'),
                )),
          if (_expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Total group spend: ₹${totalSpent.toStringAsFixed(2)} '
                  '(₹${_members.isEmpty ? 0 : (totalSpent / _members.length).toStringAsFixed(2)} per person)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          const Divider(height: 32),

          Center(
            child: ElevatedButton.icon(
              onPressed: _computing || _expenses.isEmpty ? null : _settleUp,
              icon: _computing
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.calculate_outlined),
              label: Text(_computing ? 'Calculating...' : 'Settle Up (Minimum Transactions)'),
            ),
          ),

          if (_settlement != null) ...[
            const SizedBox(height: 20),
            const Text('3. Settlement Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_settlement!.isEmpty)
              const Text('Everyone is already settled up! 🎉')
            else
              ..._settlement!.map((t) => Card(
                    color: Colors.teal.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.arrow_forward, color: Colors.teal),
                      title: Text('${t.from} → ${t.to}'),
                      trailing: Text('₹${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
            const SizedBox(height: 8),
            Text('${_settlement!.length} transaction(s) needed to settle the whole group.',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
