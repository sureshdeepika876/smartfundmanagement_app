
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/expense.dart';
import '../utils/nlp_expense_parser.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Manual form fields
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _category = 'Food';
  String _paymentMethod = 'Cash';
  DateTime _date = DateTime.now();
  String _type = 'expense';
  String? _location;
  String? _mood;

  final locations = ['Home', 'College', 'Mall', 'Weekend Outing', 'Work', 'Travel', 'Other'];
  final moods = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😤', 'label': 'Stressed'},
    {'emoji': '😴', 'label': 'Bored'},
  ];

  // NLP tab
  final _nlpCtrl = TextEditingController();
  ParsedExpense? _preview;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  bool _saving = false;

  final categories = ['Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];
  final paymentMethods = ['Cash', 'Card', 'UPI', 'Wallet'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _nlpCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _saveExpense({double? amount, String? category, String? note}) async {
    final amt = amount ?? double.tryParse(_amountCtrl.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    final fs = context.read<FirestoreService>();
    final expense = Expense(
      id: '',
      userId: '',
      amount: amt,
      category: category ?? _category,
      note: note ?? _noteCtrl.text,
      paymentMethod: _paymentMethod,
      date: _date,
      type: _type,
      location: _location,
      mood: _mood,
    );
    await fs.addExpense(expense);
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  // ---------------- NLP TAB ----------------
  void _previewNlp() {
    final text = _nlpCtrl.text.trim();
    if (text.isEmpty) return;
    // Try backend NLP first for better accuracy, fall back to local regex parser.
    final api = ApiService(context.read<AuthService>());
    api.parseExpenseText(text).then((result) {
      setState(() {
        _preview = ParsedExpense(
          amount: (result['amount'] as num?)?.toDouble(),
          category: result['category'] ?? 'Other',
          merchant: result['merchant'],
          date: DateTime.tryParse(result['date'] ?? '') ?? DateTime.now(),
          note: text,
        );
      });
    }).catchError((_) {
      setState(() => _preview = NlpExpenseParser.parse(text));
    });
  }

  Future<void> _toggleListening() async {
    if (!_listening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _listening = true);
        _speech.listen(onResult: (result) {
          setState(() => _nlpCtrl.text = result.recognizedWords);
          if (result.finalResult) {
            setState(() => _listening = false);
            _previewNlp();
          }
        });
      }
    } else {
      setState(() => _listening = false);
      _speech.stop();
    }
  }

  // ---------------- OCR TAB ----------------
  Future<void> _scanReceipt() async {
  final picker = ImagePicker();

  try {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (picked == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _saving = true;
    });

    final api = ApiService(
      context.read<AuthService>(),
    );

    final result = await api.scanReceipt(picked);

    if (!mounted) return;

    final amount = (result['amount'] as num?)?.toDouble();

    setState(() {
      _preview = ParsedExpense(
        amount: amount,
        category: result['category']?.toString() ?? 'Other',
        merchant: result['merchant']?.toString(),
        date: DateTime.tryParse(
              result['date']?.toString() ?? '',
            ) ??
            DateTime.now(),
        note: result['merchant']?.toString() ?? 'Receipt scan',
      );

      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Receipt scanned successfully'),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Receipt scan failed: $e',
        ),
      ),
    );
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Quick (NLP)', icon: Icon(Icons.chat_bubble_outline)),
          Tab(text: 'Manual', icon: Icon(Icons.edit_note)),
          Tab(text: 'Scan Receipt', icon: Icon(Icons.camera_alt_outlined)),
        ]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNlpTab(), _buildManualTab(), _buildOcrTab()],
      ),
    );
  }

  Widget _buildNlpTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Just type or speak naturally:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('"spent 250 on lunch with friends at Domino\'s"', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _nlpCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Type your expense...',
              suffixIcon: IconButton(
                icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : null),
                onPressed: _toggleListening,
              ),
            ),
            onChanged: (_) => _previewNlp(),
          ),
          const SizedBox(height: 16),
          if (_preview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Amount: ₹${_preview!.amount?.toStringAsFixed(2) ?? "—"}'),
                    Text('Category: ${_preview!.category}'),
                    if (_preview!.merchant != null) Text('Merchant: ${_preview!.merchant}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving || _preview!.amount == null
                  ? null
                  : () => _saveExpense(
                      amount: _preview!.amount, category: _preview!.category, note: _preview!.note),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm & Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense')),
              ButtonSegment(value: 'income', label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
            items: paymentMethods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _paymentMethod = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date: ${_date.toLocal()}'.split(' ')[0]),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context, initialDate: _date,
                firstDate: DateTime(2020), lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _location,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => _location = v),
          ),
          const SizedBox(height: 16),
          const Text('How are you feeling? (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: moods.map((m) {
              final selected = _mood == m['label'];
              return ChoiceChip(
                label: Text('${m['emoji']} ${m['label']}'),
                selected: selected,
                onSelected: (_) => setState(() => _mood = selected ? null : m['label']),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : () => _saveExpense(),
            child: _saving
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Take a photo of your receipt.\nWe\'ll extract amount, merchant, and date automatically.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _scanReceipt,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Receipt'),
          ),
          if (_saving) const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator()),
          if (_preview != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Amount: ₹${_preview!.amount?.toStringAsFixed(2) ?? "—"}'),
                    Text('Category: ${_preview!.category}'),
                    if (_preview!.merchant != null) Text('Merchant: ${_preview!.merchant}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _preview!.amount == null
                  ? null
                  : () => _saveExpense(
                      amount: _preview!.amount, category: _preview!.category, note: _preview!.note),
              child: const Text('Confirm & Save'),
            ),
          ],
        ],
      ),
    );
  }
}
