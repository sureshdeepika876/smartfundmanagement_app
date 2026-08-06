import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text, true));
      _thinking = true;
      _inputCtrl.clear();
    });
    _scrollToBottom();

    final api = ApiService(context.read<AuthService>());
    try {
      final reply = await api.askChatbot(text);
      setState(() => _messages.add(ChatMessage(reply, false)));
    } catch (e) {
      // Local fallback so the chatbot still answers basic questions if the
      // Node.js backend isn't running (common during a demo/viva).
      final fallback = await _localFallbackAnswer(text);
      setState(() => _messages.add(ChatMessage(fallback, false)));
    }
    setState(() => _thinking = false);
    _scrollToBottom();
  }

  /// Simple on-device rule-based answer using live Firestore data, used only
  /// when the backend chatbot endpoint is unreachable.
  Future<String> _localFallbackAnswer(String question) async {
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
      return "I couldn't reach the backend to check your live budget status. "
          "(Start the Node.js server for real-time budget alerts.) "
          "Meanwhile, your total spend this month is ₹${totalExpense.toStringAsFixed(2)}.";
    }
    if (lower.contains('tip') || lower.contains('advice') || lower.contains('save')) {
      return "💡 Tip: Try the 50/30/20 rule — 50% needs, 30% wants, 20% savings. "
          "Check the Analytics tab's \"What-If\" simulator to see how cutting a category by "
          "even 10-20% adds up over a year.";
    }
    if (lower.contains('forecast') || lower.contains('predict') || lower.contains('next month')) {
      return "For an accurate AI forecast based on your spending trend, please make sure "
          "the backend server is running — check the Analytics tab for the live forecast.";
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
