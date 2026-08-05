import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../widgets/summary_card.dart';
import '../widgets/expense_card.dart';
import 'add_expense_screen.dart';
import 'expense_list_screen.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'chatbot_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(),
      const ExpenseListScreen(embedded: true),
      const AnalyticsScreen(embedded: true),
      const BudgetScreen(embedded: true),
      const SettingsScreen(embedded: true),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_navIndex]),
      floatingActionButton: _navIndex == 0 || _navIndex == 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'chatbot',
                  mini: true,
                  backgroundColor: Colors.deepPurple,
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                  child: const Icon(Icons.smart_toy_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FirestoreService>();
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();

    return StreamBuilder<List<Expense>>(
      stream: fs.streamExpensesForMonth(now.month, now.year),
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? [];
        final totalIncome = expenses.where((e) => e.type == 'income').fold(0.0, (s, e) => s + e.amount);
        final totalExpense = expenses.where((e) => e.type == 'expense').fold(0.0, (s, e) => s + e.amount);
        final balance = totalIncome - totalExpense;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF2E7D6B),
                  child: Text(
                    (user?.displayName?.isNotEmpty == true ? user!.displayName![0] : 'U').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back 👋', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(user?.displayName ?? 'User',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E7D6B), Color(0xFF57B894)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Balance', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('₹${balance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: SummaryCard(label: 'Income', amount: totalIncome, icon: Icons.arrow_downward, color: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: SummaryCard(label: 'Expense', amount: totalExpense, icon: Icons.arrow_upward, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (expenses.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No transactions yet this month.')))
            else
              ...expenses.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExpenseCard(expense: e),
                  )),
          ],
        );
      },
    );
  }
}
