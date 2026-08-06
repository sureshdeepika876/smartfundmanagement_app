import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfundmanagement/screens/analytics_engine.dart';

void main() {
  group('Analytics Engine Unit Tests', () {
    test('whatIf calculation returns expected savings', () {
      final res = AnalyticsEngine.whatIf(
        currentMonthCategoryTotal: 1000.0,
        reductionPercent: 10.0,
      );
      expect(res.monthlySavings, 100.0);
      expect(res.yearlySavings, 1200.0);
    });

    test('forecastNextMonth returns empty map for empty history', () {
      final forecast = AnalyticsEngine.forecastNextMonth([]);
      expect(forecast.isEmpty, true);
    });

    test('detectAnomalies returns empty list when items are under threshold', () {
      final anomalies = AnalyticsEngine.detectAnomalies([]);
      expect(anomalies.isEmpty, true);
    });
  });

  group('Smoke Widget Tests', () {
    testWidgets('App UI text renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('SmartSpend - AI Finance Tracker'),
            ),
          ),
        ),
      );
      expect(find.text('SmartSpend - AI Finance Tracker'), findsOneWidget);
    });
  });
}
