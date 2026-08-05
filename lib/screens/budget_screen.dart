import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../services/firestore_service.dart';
import '../models/budget.dart';
import '../models/expense.dart';

class BudgetScreen extends StatelessWidget {
  final bool embedded;
  const BudgetScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FirestoreService>();
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly Budget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showAddBudgetDialog(context)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Budget>>(
              stream: fs.streamBudgets(now.month, now.year),
              builder: (context, budgetSnap) {
                final budgets = budgetSnap.data ?? [];
                if (budgets.isEmpty) {
                  return const Center(child: Text('No budgets set yet. Tap + to add one.'));
                }
                return StreamBuilder<List<Expense>>(
                  stream: fs.streamExpensesForMonth(now.month, now.year),
                  builder: (context, expSnap) {
                    final expenses = expSnap.data ?? [];
                    return ListView.builder(
                      itemCount: budgets.length,
                      itemBuilder: (context, i) {
                        final b = budgets[i];
                        final spent = b.category == 'Overall'
                            ? expenses.where((e) => e.type == 'expense').fold(0.0, (s, e) => s + e.amount)
                            : expenses.where((e) => e.category == b.category && e.type == 'expense').fold(0.0, (s, e) => s + e.amount);
                        final ratio = b.limit == 0 ? 0.0 : (spent / b.limit).clamp(0, 1.5);
                        final overBudget = spent > b.limit;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(b.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (overBudget)
                                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearPercentIndicator(
                                  lineHeight: 12,
                                  percent: ratio > 1 ? 1 : ratio.toDouble(),
                                  backgroundColor: Colors.grey.shade200,
                                  progressColor: overBudget ? Colors.red : const Color(0xFF2E7D6B),
                                  barRadius: const Radius.circular(8),
                                ),
                                const SizedBox(height: 6),
                                Text('₹${spent.toStringAsFixed(0)} of ₹${b.limit.toStringAsFixed(0)} '
                                    '(₹${(b.limit - spent).toStringAsFixed(0)} remaining)',
                                    style: TextStyle(fontSize: 12, color: overBudget ? Colors.red : Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final categories = ['Overall', 'Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];
    String category = 'Overall';
    final limitCtrl = TextEditingController();
    final now = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: category,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => category = v!,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Limit (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final limit = double.tryParse(limitCtrl.text) ?? 0;
              if (limit > 0) {
                context.read<FirestoreService>().setBudget(Budget(
                    id: '', category: category, limit: limit, month: now.month, year: now.year));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
