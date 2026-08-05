import 'dart:math' as math;
import '../models/expense.dart';

/// On-device replacement for what used to be a Node.js backend's
/// /analytics/forecast, /analytics/anomalies, and /analytics/what-if routes.
/// Everything here runs against the Expense list already synced from
/// Firestore — no server round-trip needed.

class AnomalyResult {
  final String category;
  final double amount;
  final double deviation; // e.g. 2.3x the category's normal average
  final DateTime date;
  AnomalyResult({
    required this.category,
    required this.amount,
    required this.deviation,
    required this.date,
  });
}

class AnalyticsEngine {
  /// Simple moving-average forecast: for each category, averages that
  /// category's spend over the last [months] completed months to predict
  /// next month's spend. Categories need at least one prior month of data.
  static Map<String, double> forecastNextMonth(List<Expense> history, {int months = 3}) {
    final now = DateTime.now();
    final currentKey = now.year * 12 + now.month;

    // monthlyTotals[category][year*12+month] = total spent that month
    final monthlyTotals = <String, Map<int, double>>{};
    for (final e in history.where((e) => e.type == 'expense')) {
      final key = e.date.year * 12 + e.date.month;
      if (key >= currentKey) continue; // exclude the current, still-in-progress month
      monthlyTotals.putIfAbsent(e.category, () => {});
      monthlyTotals[e.category]![key] = (monthlyTotals[e.category]![key] ?? 0) + e.amount;
    }

    final forecast = <String, double>{};
    for (final entry in monthlyTotals.entries) {
      final keys = entry.value.keys.toList()..sort();
      final lastN = keys.length > months ? keys.sublist(keys.length - months) : keys;
      if (lastN.isEmpty) continue;
      final avg = lastN.map((k) => entry.value[k]!).reduce((a, b) => a + b) / lastN.length;
      forecast[entry.key] = avg;
    }
    return forecast;
  }

  /// z-score based anomaly detection: flags THIS month's transactions that
  /// are unusually large compared to that category's historical average.
  /// Needs at least 4 prior transactions in a category for stats to be
  /// meaningful — categories with less history are skipped rather than
  /// producing noisy false positives.
  static List<AnomalyResult> detectAnomalies(List<Expense> history, {double zThreshold = 2.0}) {
    final now = DateTime.now();
    final byCategory = <String, List<Expense>>{};
    for (final e in history.where((e) => e.type == 'expense')) {
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }

    final anomalies = <AnomalyResult>[];
    for (final entry in byCategory.entries) {
      final all = entry.value;
      if (all.length < 4) continue;

      final amounts = all.map((e) => e.amount).toList();
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance =
          amounts.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) / amounts.length;
      final stdDev = math.sqrt(variance);
      if (stdDev == 0 || mean == 0) continue;

      for (final e in all.where((e) => e.date.year == now.year && e.date.month == now.month)) {
        final z = (e.amount - mean) / stdDev;
        if (z > zThreshold) {
          anomalies.add(AnomalyResult(
            category: entry.key,
            amount: e.amount,
            deviation: double.parse((e.amount / mean).toStringAsFixed(1)),
            date: e.date,
          ));
        }
      }
    }
    anomalies.sort((a, b) => b.deviation.compareTo(a.deviation));
    return anomalies;
  }

  /// "What-if" simulation: pure arithmetic, no history needed beyond the
  /// current month's total for the chosen category.
  static ({double monthlySavings, double yearlySavings}) whatIf({
    required double currentMonthCategoryTotal,
    required double reductionPercent,
  }) {
    final monthlySavings = currentMonthCategoryTotal * (reductionPercent / 100);
    return (monthlySavings: monthlySavings, yearlySavings: monthlySavings * 12);
  }
}