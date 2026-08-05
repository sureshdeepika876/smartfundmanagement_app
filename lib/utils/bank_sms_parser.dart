/// Parses bank/UPI transaction SMS (the kind banks send for debits and
/// credits) into a structured transaction we can save as an [Expense].
///
/// Handles common Indian bank SMS formats, e.g.:
///   "Rs.500.00 debited from A/c XX1234 on 29-07-26 to VPA merchant@upi
///    Avl Bal Rs.2,500.00"
///   "INR 12,000.00 credited to A/c XX1234 on 01-08-26. Avl Bal INR 45,000"
///   "Your A/c XX1234 debited by Rs 250 for UPI/DR/12345/SWIGGY/... Bal Rs 4000"
///
/// This is a heuristic, rule-based parser (no network/AI call needed), so it
/// runs instantly on-device for both the Android auto-read flow and the
/// manual paste flow (iOS / any platform).
class ParsedBankTransaction {
  final double? amount;
  final String type; // 'expense' or 'income'
  final String category;
  final String? merchant;
  final String? bank;
  final String? accountLast4;
  final double? balanceAfter;
  final DateTime date;
  final String rawText;

  ParsedBankTransaction({
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.bank,
    required this.accountLast4,
    required this.balanceAfter,
    required this.date,
    required this.rawText,
  });
}

class BankSmsParser {
  // Words that indicate money left the account.
  static final List<String> _debitKeywords = [
    'debited', 'debit', 'spent', 'withdrawn', 'paid', 'purchase of', 'sent',
  ];

  // Words that indicate money entered the account.
  static final List<String> _creditKeywords = [
    'credited', 'credit', 'received', 'deposited', 'refund',
  ];

  static final RegExp _amountNearKeyword = RegExp(
    r'(?:rs\.?|inr)\s?\.?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _balanceRegex = RegExp(
    r'(?:avl\s*bal|available\s*bal(?:ance)?|bal)\.?:?\s*(?:rs\.?|inr)?\s?\.?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _accountRegex = RegExp(
    r'a\/?c\s*(?:no\.?)?\s*[x\*]*(\d{4})',
    caseSensitive: false,
  );

  static final Map<String, List<String>> _categoryKeywords = {
    'Food': ['swiggy', 'zomato', 'lunch', 'dinner', 'restaurant', 'cafe', 'food'],
    'Travel': ['uber', 'ola', 'irctc', 'fuel', 'petrol', 'diesel', 'cab', 'redbus'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'shopping', 'mall'],
    'Bills': ['electricity', 'water bill', 'rent', 'wifi', 'broadband', 'recharge', 'subscription', 'bill'],
    'Entertainment': ['netflix', 'spotify', 'hotstar', 'bookmyshow', 'movie'],
    'Health': ['pharmacy', 'hospital', 'medplus', 'apollo', 'medicine'],
  };

  /// Quick check used to filter an inbox / incoming SMS stream down to only
  /// messages that look like bank transaction alerts, before we bother
  /// running the full parse.
  static bool looksLikeBankSms(String text) {
    final lower = text.toLowerCase();
    final hasAmount = _amountNearKeyword.hasMatch(lower);
    final hasVerb = [..._debitKeywords, ..._creditKeywords].any((k) => lower.contains(k));
    return hasAmount && hasVerb;
  }

  static ParsedBankTransaction? parse(String text) {
    final lower = text.toLowerCase();
    if (!looksLikeBankSms(text)) return null;

    // 1. amount — first Rs./INR figure in the message.
    double? amount;
    final amtMatch = _amountNearKeyword.firstMatch(lower);
    if (amtMatch != null) {
      amount = double.tryParse(amtMatch.group(1)!.replaceAll(',', ''));
    }

    // 2. debit or credit
    final isDebit = _debitKeywords.any((k) => lower.contains(k));
    final isCredit = _creditKeywords.any((k) => lower.contains(k));
    final type = (isCredit && !isDebit) ? 'income' : 'expense';

    // 3. running balance after the transaction (if mentioned)
    double? balanceAfter;
    final balMatch = _balanceRegex.firstMatch(lower);
    if (balMatch != null) {
      balanceAfter = double.tryParse(balMatch.group(1)!.replaceAll(',', ''));
    }

    // 4. last 4 digits of account
    String? accountLast4;
    final acMatch = _accountRegex.firstMatch(lower);
    if (acMatch != null) accountLast4 = acMatch.group(1);

    // 5. merchant — text after common connector phrases.
    String? merchant = _extractMerchant(text);

    // 6. category
    String category = 'Other';
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any((kw) => lower.contains(kw)) ||
          (merchant != null && entry.value.any((kw) => merchant!.toLowerCase().contains(kw)))) {
        category = entry.key;
        break;
      }
    }
    if (category == 'Other' && type == 'income') category = 'Income';

    return ParsedBankTransaction(
      amount: amount,
      type: type,
      category: category,
      merchant: merchant,
      bank: null,
      accountLast4: accountLast4,
      balanceAfter: balanceAfter,
      date: DateTime.now(),
      rawText: text,
    );
  }

  static String? _extractMerchant(String text) {
    final lower = text.toLowerCase();
    // "to VPA name@bank" / "trf to NAME" / "at NAME" / "for UPI/DR/ref/NAME/..."
    final patterns = [
      RegExp(r'(?:to|at)\s+vpa\s+([a-z0-9._@\-]+)', caseSensitive: false),
      RegExp(r'trf\s+to\s+([a-z0-9 .&\-]+)', caseSensitive: false),
      RegExp(r'\bat\s+([a-z0-9 .&\-]{2,30})', caseSensitive: false),
      RegExp(r'upi\/(?:dr|cr)\/\d+\/([a-z0-9 .&\-]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null && m.group(1) != null) {
        var raw = m.group(1)!.trim();
        raw = raw.split(RegExp(r'[.,!\n]'))[0].trim();
        if (raw.isNotEmpty) {
          // Recover original casing from the source text where possible.
          final idx = lower.indexOf(raw);
          return idx != -1 ? text.substring(idx, idx + raw.length).trim() : raw;
        }
      }
    }
    return null;
  }
}
