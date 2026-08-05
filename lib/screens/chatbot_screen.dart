import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import 'analytics_engine.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
        "Hi! I'm your SmartSpend assistant 🤖\nAsk me things like:\n"
            "• \"How much did I spend on Food this month?\"\n"
            "• \"Am I over budget?\"\n"
            "• \"Give me a savings tip\"\n"
            "• \"What's my forecast for next month?\"",
        false),
  ];
  bool _thinking = false;

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text, true));
      _thinking = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    // Fully on-device — queries Firestore directly, no backend involved.
    final reply = await _answer(text);
    setState(() {
      _messages.add(ChatMessage(reply, false));
      _thinking = false;
    });
    _scrollToBottom();
  }

  /// Simple rule-based answer using live Firestore data.
  Future<String> _answer(String question) async {
    final fs = context.read<FirestoreService>();
    final now = DateTime.now();
    final expenses = await fs.streamExpensesForMonth(now.month, now.year).first;
    final lower = question.toLowerCase();

    final totalExpense = expenses.where((e) => e.type == 'expense').fold(0.0, (s, e) => s + e.amount);
    final totalIncome = expenses.where((e) => e.type == 'income').fold(0.0, (s, e) => s + e.amount);

    for (final cat in ['food', 'travel', 'shopping', 'bills', 'entertainment', 'health', 'education']) {
      if (lower.contains(cat)) {
        final catTotal = expenses
            .where((e) => e.category.toLowerCase() == cat && e.type == 'expense')
            .fold(0.0, (s, e) => s + e.amount);
        return "You've spent ₹${catTotal.toStringAsFixed(2)} on ${cat[0].toUpperCase()}${cat.substring(1)} this month.";
      }
    }

    if (lower.contains('balance')) {
      return "Your current month balance is ₹${(totalIncome - totalExpense).toStringAsFixed(2)} "
          "(Income ₹${totalIncome.toStringAsFixed(0)} − Expense ₹${totalExpense.toStringAsFixed(0)}).";
    }

    if (lower.contains('budget') || lower.contains('over')) {
      final budgets = await fs.streamBudgets(now.month, now.year).first;
      if (budgets.isEmpty) {
        return "You haven't set a budget for this month yet — head to the Budget tab to set one, "
            "so far you've spent ₹${totalExpense.toStringAsFixed(2)}.";
      }
      final byCategory = <String, double>{};
      for (final e in expenses.where((e) => e.type == 'expense')) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
      }
      final overBudget = budgets.where((b) {
        final spent = b.category == 'Overall' ? totalExpense : (byCategory[b.category] ?? 0);
        return spent > b.limit;
      }).toList();
      if (overBudget.isEmpty) {
        return "You're within budget on everything so far this month. Nice work! 👍";
      }
      final lines = overBudget.map((b) {
        final spent = b.category == 'Overall' ? totalExpense : (byCategory[b.category] ?? 0);
        return "${b.category}: ₹${spent.toStringAsFixed(0)} of ₹${b.limit.toStringAsFixed(0)}";
      }).join('\n');
      return "You're over budget on:\n$lines";
    }

    if (lower.contains('tip') || lower.contains('advice') || lower.contains('save')) {
      return "💡 Tip: Try the 50/30/20 rule — 50% needs, 30% wants, 20% savings. "
          "Check the Analytics tab's \"What-If\" simulator to see how cutting a category by "
          "even 10-20% adds up over a year.";
    }

    if (lower.contains('forecast') || lower.contains('predict') || lower.contains('next month')) {
      final history = await fs.streamExpenses(limit: 500).first;
      final forecast = AnalyticsEngine.forecastNextMonth(history);
      if (forecast.isEmpty) {
        return "I need at least a month of past spending to forecast next month — keep logging expenses "
            "and check back, or see live projections any time in the Analytics tab.";
      }
      final total = forecast.values.fold(0.0, (s, v) => s + v);
      final top = forecast.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topLine = top.take(3).map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ');
      return "Based on your recent spending trend, next month's forecast is about ₹${total.toStringAsFixed(0)} total. "
          "Biggest categories: $topLine. Full breakdown is in the Analytics tab.";
    }

    return "I'm not sure about that one yet. Try asking about a specific category "
        "(e.g. \"Food spending\"), your balance, budget status, or for a savings tip.";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 AI Finance Assistant')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                final msg = _messages[i];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF2E7D6B) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your spending...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}