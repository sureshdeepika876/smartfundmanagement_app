import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

const Map<String, IconData> categoryIcons = {
  'Food': Icons.fastfood,
  'Travel': Icons.directions_car,
  'Shopping': Icons.shopping_bag,
  'Bills': Icons.receipt_long,
  'Entertainment': Icons.movie,
  'Health': Icons.local_hospital,
  'Education': Icons.school,
  'Other': Icons.category,
};

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({super.key, required this.expense, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = expense.type == 'income';
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: onTap,
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: expense.isAnomaly ? Colors.red.shade50 : Colors.teal.shade50,
          child: Icon(
            categoryIcons[expense.category] ?? Icons.category,
            color: expense.isAnomaly ? Colors.red : Colors.teal,
          ),
        ),
        title: Text(expense.note.isEmpty ? expense.category : expense.note),
        subtitle: Text('${expense.category} • ${DateFormat.yMMMd().format(expense.date)}'
            '${expense.isAnomaly ? " • ⚠ Unusual" : ""}'),
        trailing: Text(
          '${isIncome ? '+' : '-'}₹${expense.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green : Colors.black87,
          ),
        ),
      ),
    );
  }
}
