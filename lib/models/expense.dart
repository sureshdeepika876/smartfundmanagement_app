import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String note;
  final String paymentMethod; // Cash, Card, UPI, Wallet
  final DateTime date;
  final String type; // 'expense' or 'income'
  final String? location;
  final String? receiptImageUrl;
  final bool isAnomaly; // flagged by anomaly detector
  final String? mood; // 😊 happy, 😐 neutral, 😔 sad, 😤 stressed, 😴 bored — for mood-spend correlation

  Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.note,
    required this.paymentMethod,
    required this.date,
    this.type = 'expense',
    this.location,
    this.receiptImageUrl,
    this.isAnomaly = false,
    this.mood,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'category': category,
      'note': note,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'type': type,
      'location': location,
      'receiptImageUrl': receiptImageUrl,
      'isAnomaly': isAnomaly,
      'mood': mood,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      note: map['note'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? 'expense',
      location: map['location'],
      receiptImageUrl: map['receiptImageUrl'],
      isAnomaly: map['isAnomaly'] ?? false,
      mood: map['mood'],
    );
  }
}
