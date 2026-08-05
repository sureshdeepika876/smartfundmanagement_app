import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/firestore_service.dart';
import '../services/sms_service.dart';
import '../models/expense.dart';
import '../utils/nlp_expense_parser.dart';
import '../utils/bank_sms_parser.dart';

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

  // Scan Receipt tab - editable review fields (populated after OCR runs,
  // so the user can correct misreads before saving)
  final _ocrAmountCtrl = TextEditingController();
  final _ocrNoteCtrl = TextEditingController();
  String _ocrCategory = 'Food';
  String _ocrType = 'expense';
  bool _ocrHasResult = false;

  // Bank SMS tab
  final SmsService _smsService = SmsService();
  final _smsPasteCtrl = TextEditingController();
  ParsedBankTransaction? _pastePreview;
  List<ParsedBankTransaction> _smsResults = [];
  final Set<int> _selectedSmsIndices = {};
  bool _scanningSms = false;
  String? _smsError;
  DateTimeRange? _smsDateRange; // optional — null means "all time"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _nlpCtrl.dispose();
    _ocrAmountCtrl.dispose();
    _ocrNoteCtrl.dispose();
    _smsPasteCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense({double? amount, String? category, String? note, String? type}) async {
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
      type: type ?? _type,
      location: _location,
      mood: _mood,
    );
    await fs.addExpense(expense);
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  // ---------------- BANK SMS TAB ----------------
  Future<void> _scanSmsInbox() async {
    setState(() {
      _scanningSms = true;
      _smsError = null;
    });
    final granted = await _smsService.requestPermission();
    if (!granted) {
      setState(() {
        _scanningSms = false;
        _smsError = 'SMS permission denied. Enable it in app settings to auto-import bank SMS.';
      });
      return;
    }
    final results = await _smsService.scanInboxForTransactions(
      startDate: _smsDateRange?.start,
      // include the whole end day, not just midnight
      endDate: _smsDateRange != null
          ? _smsDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1))
          : null,
    );
    setState(() {
      _smsResults = results;
      _selectedSmsIndices
        ..clear()
        ..addAll(List.generate(results.length, (i) => i));
      _scanningSms = false;
    });
  }

  Future<void> _pickSmsDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _smsDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) {
      setState(() => _smsDateRange = picked);
    }
  }

  Future<void> _importSelectedSms() async {
    if (_selectedSmsIndices.isEmpty) return;
    setState(() => _saving = true);
    final fs = context.read<FirestoreService>();
    for (final i in _selectedSmsIndices) {
      final t = _smsResults[i];
      if (t.amount == null) continue;
      await fs.addExpense(Expense(
        id: '',
        userId: '',
        amount: t.amount!,
        category: t.category,
        note: t.merchant ?? t.rawText,
        paymentMethod: 'UPI',
        date: t.date,
        type: t.type,
      ));
    }
    setState(() {
      _saving = false;
      _smsResults = [];
      _selectedSmsIndices.clear();
    });
    if (mounted) Navigator.pop(context);
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _parsePastedSms() {
    final text = _smsPasteCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _pastePreview = null);
      return;
    }
    setState(() => _pastePreview = BankSmsParser.parse(text));
  }

  // ---------------- NLP TAB ----------------
  void _previewNlp() {
    final text = _nlpCtrl.text.trim();
    if (text.isEmpty) return;
    // Fully on-device, instant — no network call.
    setState(() => _preview = NlpExpenseParser.parse(text));
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
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Receipt scanning needs a phone camera — try the Quick (NLP) or Manual tab on web.'),
      ));
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    setState(() => _saving = true);

    try {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(picked.path);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      final ocrText = recognized.text;
      if (ocrText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read any text from that photo. Try again with better lighting.')));
        setState(() => _saving = false);
        return;
      }

      final parsed = NlpExpenseParser.parse(ocrText);
      setState(() {
        _preview = parsed;
        _ocrAmountCtrl.text = parsed.amount?.toStringAsFixed(2) ?? '';
        _ocrNoteCtrl.text = parsed.merchant ?? parsed.note ?? '';
        _ocrCategory = categories.contains(parsed.category) ? parsed.category : 'Other';
        _ocrType = 'expense';
        _ocrHasResult = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Receipt scan failed. ($e)')));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        bottom: TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: 'Quick (NLP)', icon: Icon(Icons.chat_bubble_outline)),
          Tab(text: 'Manual', icon: Icon(Icons.edit_note)),
          Tab(text: 'Scan Receipt', icon: Icon(Icons.camera_alt_outlined)),
          Tab(text: 'Bank SMS', icon: Icon(Icons.sms_outlined)),
        ]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNlpTab(), _buildManualTab(), _buildOcrTab(), _buildSmsTab()],
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
              child: _saving ? const CircularProgressIndicator() : const Text('Confirm & Save'),
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
            child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_ocrHasResult) ...[
            const SizedBox(height: 40),
            const Icon(Icons.receipt_long, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Take a photo of your receipt.\nWe\'ll try to extract the amount, merchant, and category automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _scanReceipt,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Receipt'),
              ),
            ),
            if (_saving) const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator())),
          ] else ...[
            // Warning banner — this is the key addition
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt scanning can make mistakes. Please review and correct the details below before saving.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_ocrType},
              onSelectionChanged: (s) => setState(() => _ocrType = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ocrAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                helperText: 'Double-check this against your receipt',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ocrCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _ocrCategory = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ocrNoteCtrl,
              decoration: const InputDecoration(labelText: 'Merchant / Note', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                      _ocrHasResult = false;
                      _preview = null;
                      _ocrAmountCtrl.clear();
                      _ocrNoteCtrl.clear();
                    }),
                    child: const Text('Rescan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                      // Doesn't trust the scan at all — send them to Manual
                      // with nothing pre-filled to avoid propagating a bad read.
                      setState(() {
                        _ocrHasResult = false;
                        _preview = null;
                      });
                      _tabController.animateTo(1);
                    },
                    child: const Text('Enter Manually'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving || double.tryParse(_ocrAmountCtrl.text) == null
                  ? null
                  : () => _saveExpense(
                amount: double.tryParse(_ocrAmountCtrl.text),
                category: _ocrCategory,
                note: _ocrNoteCtrl.text,
                type: _ocrType,
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirm & Save'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- BANK SMS TAB ----------------
  Widget _buildSmsTab() {
    if (_smsService.isSupported) {
      return _buildSmsAutoScanTab();
    }
    return _buildSmsPasteTab();
  }

  Widget _buildSmsAutoScanTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Scan your SMS inbox for bank/UPI transaction alerts.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('We only read messages that look like bank debit/credit alerts — nothing else leaves your device.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanningSms ? null : _pickSmsDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _smsDateRange == null
                        ? 'Date range (optional)'
                        : '${_fmtDate(_smsDateRange!.start)} – ${_fmtDate(_smsDateRange!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_smsDateRange != null)
                IconButton(
                  tooltip: 'Clear date range',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _scanningSms ? null : () => setState(() => _smsDateRange = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _smsDateRange == null
                ? 'No range selected — will scan all messages in your inbox.'
                : 'Only messages within this range will be scanned.',
            style: const TextStyle(color: Colors.grey, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _scanningSms ? null : _scanSmsInbox,
            icon: const Icon(Icons.sms_outlined),
            label: Text(_scanningSms ? 'Scanning...' : 'Scan SMS Inbox'),
          ),
          if (_smsError != null) ...[
            const SizedBox(height: 12),
            Text(_smsError!, style: const TextStyle(color: Colors.red)),
          ],
          if (_scanningSms) const Padding(padding: EdgeInsets.only(top: 20), child: LinearProgressIndicator()),
          if (!_scanningSms && _smsResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('${_smsResults.length} transaction${_smsResults.length == 1 ? '' : 's'} found — select which to import:',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _smsResults.length,
                itemBuilder: (context, i) {
                  final t = _smsResults[i];
                  final isIncome = t.type == 'income';
                  return CheckboxListTile(
                    value: _selectedSmsIndices.contains(i),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedSmsIndices.add(i);
                      } else {
                        _selectedSmsIndices.remove(i);
                      }
                    }),
                    title: Text(
                      '${isIncome ? '+' : '-'}₹${t.amount?.toStringAsFixed(2) ?? '—'}  ${t.category}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red),
                    ),
                    subtitle: Text(t.merchant ?? t.rawText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving || _selectedSmsIndices.isEmpty ? null : _importSelectedSms,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Import ${_selectedSmsIndices.length} selected'),
            ),
          ] else if (!_scanningSms) ...[
            const Spacer(),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No transactions scanned yet.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmsPasteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Paste a bank/UPI transaction SMS:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Automatic SMS reading isn\'t available on this platform — paste or share the SMS text here instead.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _smsPasteCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. Rs.500.00 debited from A/c XX1234 on 29-07-26 to VPA merchant@upi Avl Bal Rs.2,500.00',
            ),
            onChanged: (_) => _parsePastedSms(),
          ),
          const SizedBox(height: 16),
          if (_pastePreview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Type: ${_pastePreview!.type == 'income' ? 'Income (credit)' : 'Expense (debit)'}'),
                    Text('Amount: ₹${_pastePreview!.amount?.toStringAsFixed(2) ?? "—"}'),
                    Text('Category: ${_pastePreview!.category}'),
                    if (_pastePreview!.merchant != null) Text('Merchant: ${_pastePreview!.merchant}'),
                    if (_pastePreview!.balanceAfter != null)
                      Text('Balance after: ₹${_pastePreview!.balanceAfter!.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving || _pastePreview!.amount == null
                  ? null
                  : () => _saveExpense(
                amount: _pastePreview!.amount,
                category: _pastePreview!.category,
                note: _pastePreview!.merchant ?? _pastePreview!.rawText,
                type: _pastePreview!.type,
              ),
              child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Save'),
            ),
          ] else if (_smsPasteCtrl.text.trim().isNotEmpty)
            const Text('Couldn\'t detect a transaction in that text.', style: TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }
}