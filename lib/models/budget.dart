class Budget {
  final String id;
  final String category; // 'Overall' for total monthly budget
  final double limit;
  final int month; // 1-12
  final int year;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'limit': limit,
        'month': month,
        'year': year,
      };

  factory Budget.fromMap(String id, Map<String, dynamic> map) => Budget(
        id: id,
        category: map['category'] ?? 'Overall',
        limit: (map['limit'] ?? 0).toDouble(),
        month: map['month'] ?? DateTime.now().month,
        year: map['year'] ?? DateTime.now().year,
      );
}

class SavingsGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String icon;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    this.icon = '🎯',
  });

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1).toDouble();

  bool get isAchieved => currentAmount >= targetAmount;

  Map<String, dynamic> toMap() => {
        'title': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'deadline': deadline.toIso8601String(),
        'icon': icon,
      };

  factory SavingsGoal.fromMap(String id, Map<String, dynamic> map) =>
      SavingsGoal(
        id: id,
        title: map['title'] ?? '',
        targetAmount: (map['targetAmount'] ?? 0).toDouble(),
        currentAmount: (map['currentAmount'] ?? 0).toDouble(),
        deadline: DateTime.tryParse(map['deadline'] ?? '') ?? DateTime.now(),
        icon: map['icon'] ?? '🎯',
      );
}
