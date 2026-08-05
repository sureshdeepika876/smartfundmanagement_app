import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import 'analytics_engine.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool embedded;
  const AnalyticsScreen({super.key, this.embedded = false});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, double>? _forecast;
  List<AnomalyResult>? _anomalies;
  ({double monthlySavings, double yearlySavings})? _whatIfResult;
  String _simCategory = 'Food';
  double _simReduction = 20;

  // Current month's spend per category, kept in sync from the StreamBuilder
  // below so the what-if simulator has real numbers to work with.
  Map<String, double> _currentMonthByCategory = {};

  final categories = ['Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Education', 'Other'];

  /// Pulls a wider window of history (several months) once, then runs
  /// forecasting and anomaly detection entirely on-device — no server call.
  Future<void> _loadAiInsights() async {
    final fs = context.read<FirestoreService>();
    final history = await fs.streamExpenses(limit: 500).first;
    setState(() {
      _forecast = AnalyticsEngine.forecastNextMonth(history);
      _anomalies = AnalyticsEngine.detectAnomalies(history);
    });
  }

  void _runWhatIf() {
    final total = _currentMonthByCategory[_simCategory] ?? 0.0;
    setState(() {
      _whatIfResult = AnalyticsEngine.whatIf(
        currentMonthCategoryTotal: total,
        reductionPercent: _simReduction,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAiInsights();
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.watch<FirestoreService>();
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<List<Expense>>(
        stream: fs.streamExpensesForMonth(now.month, now.year),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          final byCategory = <String, double>{};
          for (final e in expenses.where((e) => e.type == 'expense')) {
            byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
          }
          final total = byCategory.values.fold(0.0, (s, v) => s + v);

          // Keep the what-if simulator's data current without triggering a
          // rebuild loop (only setState when the totals actually change).
          if (!_mapsEqual(_currentMonthByCategory, byCategory)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _currentMonthByCategory = byCategory);
            });
          }

          return ListView(
            children: [
              const Text('Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (byCategory.isNotEmpty) ...[
                const Text('Spending by Category', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PieChart(PieChartData(
                    sections: byCategory.entries.map((e) {
                      final pct = total == 0 ? 0 : (e.value / total * 100);
                      return PieChartSectionData(
                        value: e.value,
                        title: '${pct.toStringAsFixed(0)}%',
                        radius: 70,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        color: Colors.primaries[byCategory.keys.toList().indexOf(e.key) % Colors.primaries.length],
                      );
                    }).toList(),
                    sectionsSpace: 2,
                  )),
                ),
                const SizedBox(height: 24),
              ],

              if (_anomalies != null && _anomalies!.isNotEmpty) ...[
                const Text('⚠ Anomaly Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._anomalies!.map((a) => Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    title: Text('₹${a.amount.toStringAsFixed(0)} on ${a.category}'),
                    subtitle: Text('Unusual: ~${a.deviation}x your average for this category'),
                  ),
                )),
                const SizedBox(height: 16),
              ],

              if (_forecast != null && _forecast!.isNotEmpty) ...[
                const Text('📈 Next Month Forecast', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _forecast!.entries
                          .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(e.key), Text('₹${e.value.toStringAsFixed(0)}')],
                        ),
                      ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (_forecast != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Add a couple of months of expenses to unlock next-month forecasts.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],

              // ---------- Location-aware insights ----------
              if (expenses.any((e) => e.location != null && e.location!.isNotEmpty)) ...[
                const Text('📍 Location Insights', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final byLocation = <String, double>{};
                  for (final e in expenses.where((e) => e.type == 'expense' && e.location != null)) {
                    byLocation[e.location!] = (byLocation[e.location!] ?? 0) + e.amount;
                  }
                  final sorted = byLocation.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                  final grandTotal = byLocation.values.fold(0.0, (s, v) => s + v);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sorted.map((e) {
                          final pct = grandTotal == 0 ? 0 : (e.value / grandTotal * 100);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(e.key),
                                ]),
                                Text('₹${e.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // ---------- Mood-Linked Spending Correlation ----------
              if (expenses.any((e) => e.mood != null)) ...[
                const Text('🎭 Mood-Spending Correlation', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Average spend per mood this month — see if feelings drive spending.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final moodEmoji = {
                    'Happy': '😊', 'Neutral': '😐', 'Sad': '😔', 'Stressed': '😤', 'Bored': '😴',
                  };
                  final byMoodTotal = <String, double>{};
                  final byMoodCount = <String, int>{};
                  for (final e in expenses.where((e) => e.type == 'expense' && e.mood != null)) {
                    byMoodTotal[e.mood!] = (byMoodTotal[e.mood!] ?? 0) + e.amount;
                    byMoodCount[e.mood!] = (byMoodCount[e.mood!] ?? 0) + 1;
                  }
                  final entries = byMoodTotal.entries.toList()
                    ..sort((a, b) => (b.value / byMoodCount[b.key]!).compareTo(a.value / byMoodCount[a.key]!));
                  final expenseCount = expenses.where((e) => e.type == 'expense').length;
                  final overallAvg = expenseCount == 0 ? 0.0 : total / expenseCount;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...entries.map((e) {
                            final avg = e.value / byMoodCount[e.key]!;
                            final diffPct = overallAvg == 0 ? 0 : ((avg - overallAvg) / overallAvg * 100);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${moodEmoji[e.key] ?? ''} ${e.key} (${byMoodCount[e.key]} txns)'),
                                  Text(
                                    '₹${avg.toStringAsFixed(0)} avg ${diffPct > 0 ? '(+' : '('}${diffPct.toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: diffPct > 15 ? Colors.red : (diffPct < -15 ? Colors.green : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (entries.isNotEmpty && (entries.first.value / byMoodCount[entries.first.key]!) > overallAvg * 1.15)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '💡 You tend to spend more when feeling ${entries.first.key.toLowerCase()} '
                                    '— worth watching for impulse purchases.',
                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              const Text('🧪 "What-If" Simulator', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _simCategory,
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _simCategory = v!),
                        decoration: const InputDecoration(labelText: 'Category to reduce'),
                      ),
                      Slider(
                        value: _simReduction,
                        min: 0, max: 100, divisions: 20,
                        label: '${_simReduction.toStringAsFixed(0)}%',
                        onChanged: (v) => setState(() => _simReduction = v),
                      ),
                      Text('Cut ${_simCategory} spending by ${_simReduction.toStringAsFixed(0)}%'),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _runWhatIf, child: const Text('Simulate Savings')),
                      if (_whatIfResult != null) ...[
                        const SizedBox(height: 12),
                        Text('Projected monthly savings: ₹${_whatIfResult!.monthlySavings.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('Projected yearly savings: ₹${_whatIfResult!.yearlySavings.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _mapsEqual(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}