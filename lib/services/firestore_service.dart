import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../models/budget.dart';

class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _expenses =>
      _db.collection('users').doc(_uid).collection('expenses');
  CollectionReference get _budgets =>
      _db.collection('users').doc(_uid).collection('budgets');
  CollectionReference get _goals =>
      _db.collection('users').doc(_uid).collection('goals');

  // ---------- EXPENSES ----------
  Future<void> addExpense(Expense expense) async {
    await _expenses.add(expense.toMap());
  }

  Future<void> updateExpense(Expense expense) async {
    await _expenses.doc(expense.id).update(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    await _expenses.doc(id).delete();
  }

  /// Real-time stream of expenses, most recent first.
  Stream<List<Expense>> streamExpenses({int? limit}) {
    Query q = _expenses.orderBy('date', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((snap) => snap.docs
        .map((d) => Expense.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<Expense>> streamExpensesForMonth(int month, int year) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return _expenses
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Expense.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  // ---------- BUDGETS ----------
  Future<void> setBudget(Budget budget) async {
    await _budgets.doc('${budget.year}_${budget.month}_${budget.category}')
        .set(budget.toMap());
  }

  Stream<List<Budget>> streamBudgets(int month, int year) {
    return _budgets
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Budget.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  // ---------- SAVINGS GOALS ----------
  Future<void> addGoal(SavingsGoal goal) async {
    await _goals.add(goal.toMap());
  }

  Future<void> updateGoalProgress(String id, double newCurrentAmount) async {
    await _goals.doc(id).update({'currentAmount': newCurrentAmount});
  }

  Future<void> deleteGoal(String id) async {
    await _goals.doc(id).delete();
  }

  Stream<List<SavingsGoal>> streamGoals() {
    return _goals.snapshots().map((snap) => snap.docs
        .map((d) => SavingsGoal.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }
}
