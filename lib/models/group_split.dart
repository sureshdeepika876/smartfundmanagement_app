class GroupExpenseEntry {
  final String id;
  final String payer;
  final double amount;
  final String description;

  GroupExpenseEntry({
    required this.id,
    required this.payer,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'payer': payer,
        'amount': amount,
        'description': description,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

  factory GroupExpenseEntry.fromMap(String id, Map<String, dynamic> map) =>
      GroupExpenseEntry(
        id: id,
        payer: map['payer'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        description: map['description'] ?? 'Expense',
      );
}
