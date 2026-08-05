import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../widgets/expense_card.dart';

class ExpenseListScreen extends StatefulWidget {
  final bool embedded;
  const ExpenseListScreen({super.key, this.embedded = false});
  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  String _query = '';
  String _categoryFilter = 'All';

  final categories = ['All', 'Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FirestoreService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: Text('All Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _categoryFilter == c,
                      onSelected: (_) => setState(() => _categoryFilter = c),
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: fs.streamExpenses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var expenses = snapshot.data!;
                if (_categoryFilter != 'All') {
                  expenses = expenses.where((e) => e.category == _categoryFilter).toList();
                }
                if (_query.isNotEmpty) {
                  expenses = expenses.where((e) =>
                      e.note.toLowerCase().contains(_query) ||
                      e.category.toLowerCase().contains(_query)).toList();
                }
                if (expenses.isEmpty) return const Center(child: Text('No transactions found.'));
                return ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => ExpenseCard(
                    expense: expenses[i],
                    onDelete: () => fs.deleteExpense(expenses[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
