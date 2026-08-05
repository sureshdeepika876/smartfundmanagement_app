/// Lightweight on-device fallback parser (works offline, no backend call).
/// The Node.js backend has a more powerful version; this is used when
/// offline or as an instant preview while typing.
///
/// Example: "spent 250 on lunch with friends at Domino's"
///   -> amount: 250, category: Food, merchant: Domino's
class ParsedExpense {
  final double? amount;
  final String category;
  final String? merchant;
  final DateTime date;
  final String note;

  ParsedExpense({
    required this.amount,
    required this.category,
    required this.merchant,
    required this.date,
    required this.note,
  });
}

class NlpExpenseParser {
  static final RegExp _amountRegex =
      RegExp(r'(?:rs\.?|inr|₹|\$)?\s?(\d+(?:[.,]\d{1,2})?)', caseSensitive: false);

  static final Map<String, List<String>> _categoryKeywords = {
    'Food': ['lunch', 'dinner', 'breakfast', 'restaurant', 'coffee', 'snack', 'pizza', 'zomato', 'swiggy', 'cafe'],
    'Travel': ['uber', 'ola', 'taxi', 'flight', 'train', 'bus', 'fuel', 'petrol', 'diesel', 'cab'],
    'Shopping': ['amazon', 'flipkart', 'clothes', 'shoes', 'mall', 'shopping'],
    'Bills': ['electricity', 'water bill', 'rent', 'wifi', 'internet', 'recharge', 'subscription'],
    'Entertainment': ['movie', 'netflix', 'spotify', 'concert', 'game'],
    'Health': ['medicine', 'doctor', 'hospital', 'pharmacy', 'gym'],
    'Education': ['book', 'course', 'tuition', 'fees', 'college'],
  };

  static ParsedExpense parse(String text) {
    final lower = text.toLowerCase();

    // 1. amount
    double? amount;
    final match = _amountRegex.firstMatch(lower);
    if (match != null) {
      amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
    }

    // 2. category via keyword match
    String category = 'Other';
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        category = entry.key;
        break;
      }
    }

    // 3. merchant: text after " at "
    String? merchant;
    final atIndex = lower.indexOf(' at ');
    if (atIndex != -1) {
      merchant = text.substring(atIndex + 4).trim();
      // trim trailing punctuation
      merchant = merchant.split(RegExp(r'[.,!]')).first.trim();
    }

    // 4. date: default now; look for "yesterday" / "today"
    DateTime date = DateTime.now();
    if (lower.contains('yesterday')) {
      date = date.subtract(const Duration(days: 1));
    }

    return ParsedExpense(
      amount: amount,
      category: category,
      merchant: merchant,
      date: date,
      note: text,
    );
  }
}
