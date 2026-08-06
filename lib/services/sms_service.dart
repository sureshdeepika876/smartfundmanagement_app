import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:another_telephony/telephony.dart';
import '../utils/bank_sms_parser.dart';

/// Reads and listens to device SMS on Android to auto-detect bank
/// transaction messages. SMS inbox access does not exist as a public API on
/// iOS, so every method here is a no-op there — [isSupported] tells the UI
/// to fall back to the manual "paste SMS" flow instead.
///
/// NOTE: uses `another_telephony` (a maintained fork) instead of the
/// original `telephony` package, which is discontinued and fails to build
/// on modern Android Gradle Plugin versions. The API is identical (same
/// class names: Telephony, SmsColumn, OrderBy, Sort, SmsMessage) — only the
/// import path changed.
class SmsService {
  final Telephony _telephony = Telephony.instance;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    return granted ?? false;
  }

  /// Reads the device SMS inbox and returns parsed bank transactions,
  /// most recent first. Non-bank messages are filtered out.
  ///
  /// [startDate] / [endDate] are optional (inclusive) bounds — pass both to
  /// restrict the scan to a specific date range, or leave them null to scan
  /// the full inbox (up to [limit] messages).
  Future<List<ParsedBankTransaction>> scanInboxForTransactions({
    int limit = 200,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!isSupported) return [];

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    final results = <ParsedBankTransaction>[];
    for (final msg in messages) {
      final body = msg.body;
      if (body == null || !BankSmsParser.looksLikeBankSms(body)) continue;

      final ts = msg.date;
      final msgDate = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime.now();

      if (startDate != null && msgDate.isBefore(startDate)) continue;
      if (endDate != null && msgDate.isAfter(endDate)) continue;

      final parsed = BankSmsParser.parse(body);
      if (parsed == null || parsed.amount == null) continue;
      results.add(ParsedBankTransaction(
        amount: parsed.amount,
        type: parsed.type,
        category: parsed.category,
        merchant: parsed.merchant,
        bank: msg.address,
        accountLast4: parsed.accountLast4,
        balanceAfter: parsed.balanceAfter,
        date: msgDate,
        rawText: body,
      ));

      // Only cap results once a date range is applied cheaply above; without
      // a range, stop once we've collected `limit` matching transactions
      // (previously this took the first N raw messages, which could return
      // 0 real transactions if recent SMS were all non-bank noise).
      if (startDate == null && endDate == null && results.length >= limit) break;
    }
    return results;
  }

  /// Listens for new incoming SMS while the app is in the foreground and
  /// invokes [onTransaction] whenever one looks like a bank transaction.
  /// Call [requestPermission] first.
  void listenForNewTransactions(void Function(ParsedBankTransaction) onTransaction) {
    if (!isSupported) return;
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage msg) {
        final body = msg.body;
        if (body == null || !BankSmsParser.looksLikeBankSms(body)) return;
        final parsed = BankSmsParser.parse(body);
        if (parsed == null || parsed.amount == null) return;
        onTransaction(ParsedBankTransaction(
          amount: parsed.amount,
          type: parsed.type,
          category: parsed.category,
          merchant: parsed.merchant,
          bank: msg.address,
          accountLast4: parsed.accountLast4,
          balanceAfter: parsed.balanceAfter,
          date: DateTime.now(),
          rawText: body,
        ));
      },
      listenInBackground: false,
    );
  }
}