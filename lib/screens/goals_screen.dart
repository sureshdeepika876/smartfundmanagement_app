import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/budget.dart';
import '../models/expense.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  /// Gamification: counts how many of the last 30 days had zero spending
  /// logged above a "big" threshold (₹500) — a simple proxy "streak" for
  /// disciplined spending, shown as a badge to encourage good habits.
  int _computeNoOverspendStreak(List<Expense> recentExpenses, {double bigSpendThreshold = 500}) {
    final byDay = <String, double>{};
    for (final e in recentExpenses.where((e) => e.type == 'expense')) {
      final key = '${e.date.year}-${e.date.month}-${e.date.day}';
      byDay[key] = (byDay[key] ?? 0) + e.amount;
    }
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      final spentThatDay = byDay[key] ?? 0;
      if (spentThatDay > bigSpendThreshold) break;
      streak++;
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FirestoreService>();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<SavingsGoal>>(
        stream: fs.streamGoals(),
        builder: (context, snapshot) {
          final goals = snapshot.data ?? [];
          return StreamBuilder<List<Expense>>(
            stream: fs.streamExpensesForMonth(now.month, now.year),
            builder: (context, expSnap) {
              final recentExpenses = expSnap.data ?? [];
              final streak = _computeNoOverspendStreak(recentExpenses);

              if (goals.isEmpty) {
                return Column(
                  children: [
                    _buildStreakBanner(streak),
                    const Expanded(child: Center(child: Text('No goals yet. Tap + to create one 🎯'))),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: goals.length + 1, // +1 for streak banner
                itemBuilder: (context, i) {
                  if (i == 0) return _buildStreakBanner(streak);
                  final g = goals[i - 1];
                  return _buildGoalCard(context, g);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStreakBanner(int streak) {
    final badge = streak >= 21
        ? '🥇 Gold Saver'
        : streak >= 7
            ? '🥈 Silver Saver'
            : streak >= 3
                ? '🥉 Bronze Saver'
                : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFFCC80)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$streak day streak without big overspending',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (badge != null)
                  Text(badge, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoal g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 34,
              lineWidth: 8,
              percent: g.progress,
              center: Text(g.icon, style: const TextStyle(fontSize: 20)),
              progressColor: g.isAchieved ? Colors.amber : const Color(0xFF2E7D6B),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${g.currentAmount.toStringAsFixed(0)} / ₹${g.targetAmount.toStringAsFixed(0)}'),
                  Text('By ${DateFormat.yMMMd().format(g.deadline)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (g.isAchieved)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Chip(label: Text('🏆 Achieved!'), visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showAddFundsDialog(context, g),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 90));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Savings Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Goal (e.g. Trip to Goa)')),
              TextField(controller: targetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Amount (₹)')),
              ListTile(
                title: Text('Deadline: ${DateFormat.yMMMd().format(deadline)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: deadline, firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (picked != null) setState(() => deadline = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final target = double.tryParse(targetCtrl.text) ?? 0;
                if (titleCtrl.text.isNotEmpty && target > 0) {
                  context.read<FirestoreService>().addGoal(SavingsGoal(
                      id: '', title: titleCtrl.text, targetAmount: target, currentAmount: 0, deadline: deadline));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context, SavingsGoal g) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add funds to "${g.title}"'),
        content: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final add = double.tryParse(amountCtrl.text) ?? 0;
              if (add > 0) {
                context.read<FirestoreService>().updateGoalProgress(g.id, g.currentAmount + add);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
