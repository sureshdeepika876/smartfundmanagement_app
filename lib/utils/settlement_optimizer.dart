/// Greedy min-cash-flow algorithm to minimize the number of transactions
/// needed to settle group expenses (classic "Splitwise" settlement problem).
///
/// Input: net balance per person (positive = owed money, negative = owes money)
/// Output: list of transactions {from, to, amount} that settles all debts
/// using the fewest possible transfers.
class Transaction {
  final String from;
  final String to;
  final double amount;
  Transaction(this.from, this.to, this.amount);

  Map<String, dynamic> toMap() => {
        'from': from,
        'to': to,
        'amount': double.parse(amount.toStringAsFixed(2)),
      };
}

class SettlementOptimizer {
  /// balances: map of personName -> net balance (sum should be ~0)
  static List<Transaction> optimize(Map<String, double> balances) {
    final entries = balances.entries
        .where((e) => e.value.abs() > 0.005)
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    final transactions = <Transaction>[];
    _settle(entries, transactions);
    return transactions;
  }

  static void _settle(List<MapEntry<String, double>> people, List<Transaction> result) {
    if (people.isEmpty) return;

    // Find max creditor and max debtor
    people.sort((a, b) => a.value.compareTo(b.value));
    final maxDebtor = people.first; // most negative
    final maxCreditor = people.last; // most positive

    if (maxDebtor.value.abs() < 0.005 && maxCreditor.value.abs() < 0.005) {
      return; // everyone settled
    }

    final settledAmount =
        maxDebtor.value.abs() < maxCreditor.value ? maxDebtor.value.abs() : maxCreditor.value;

    result.add(Transaction(maxDebtor.key, maxCreditor.key, settledAmount));

    final newDebtorBalance = maxDebtor.value + settledAmount;
    final newCreditorBalance = maxCreditor.value - settledAmount;

    final remaining = people.sublist(1, people.length - 1);
    remaining.add(MapEntry(maxDebtor.key, newDebtorBalance));
    remaining.add(MapEntry(maxCreditor.key, newCreditorBalance));

    _settle(remaining, result);
  }
}
