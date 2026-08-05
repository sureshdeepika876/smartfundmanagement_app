import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Talks to our Node.js + Express backend which handles
/// heavier logic: NLP parsing, OCR, forecasting, anomaly detection,
/// settlement optimization, and report generation.
class ApiService {
  // Change this to your deployed backend URL, e.g. https://smartspend-api.onrender.com
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  final AuthService _authService;
  ApiService(this._authService);

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Parses natural language text like "spent 250 on lunch with friends at Domino's"
  /// into structured expense data using the backend NLP parser.
  Future<Map<String, dynamic>> parseExpenseText(String text) async {
    final res = await http.post(
      Uri.parse('$baseUrl/nlp/parse-expense'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to parse expense text: ${res.body}');
  }

  /// Uploads a receipt image for OCR extraction (amount, merchant, date).
  Future<Map<String, dynamic>> scanReceipt(File imageFile) async {
    final uri = Uri.parse('$baseUrl/receipts/scan');
    final request = http.MultipartRequest('POST', uri);
    final token = await _authService.getIdToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('receipt', imageFile.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('OCR failed: ${res.body}');
  }

  /// Gets next-month spending forecast per category (moving average / linear regression).
  Future<Map<String, dynamic>> getForecast() async {
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/forecast'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Forecast failed: ${res.body}');
  }

  /// Runs anomaly detection (z-score/IQR) on recent expenses.
  Future<List<dynamic>> detectAnomalies() async {
    final res = await http.get(
      Uri.parse('$baseUrl/analytics/anomalies'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['anomalies'];
    throw Exception('Anomaly detection failed: ${res.body}');
  }

  /// "What-if" simulation: e.g. reduce a category's spend by X% and see projected savings.
  Future<Map<String, dynamic>> whatIfSimulation({
    required String category,
    required double reductionPercent,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/analytics/what-if'),
      headers: await _headers(),
      body: jsonEncode({
        'category': category,
        'reductionPercent': reductionPercent,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Simulation failed: ${res.body}');
  }

  /// Group expense settlement optimization (minimum number of transactions).
  Future<Map<String, dynamic>> optimizeSettlement(
      Map<String, double> netBalances) async {
    final res = await http.post(
      Uri.parse('$baseUrl/groups/settle'),
      headers: await _headers(),
      body: jsonEncode({'balances': netBalances}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Settlement optimization failed: ${res.body}');
  }

  /// Sends a message to the AI finance chatbot and gets a reply grounded
  /// in the user's real expense/budget/goal data (queried server-side).
  Future<String> askChatbot(String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chatbot/ask'),
      headers: await _headers(),
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['reply'];
    throw Exception('Chatbot request failed: ${res.body}');
  }

  /// Requests a generated PDF/Excel report link from the backend.
  Future<String> generateReport(String format, String month, String year) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reports/generate?format=$format&month=$month&year=$year'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['url'];
    throw Exception('Report generation failed: ${res.body}');
  }
}
