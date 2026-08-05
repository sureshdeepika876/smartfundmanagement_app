import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Stores user preferences (dark mode, currency, etc.) in Firestore under
/// users/{uid}/settings/preferences instead of local widget state, so they
/// persist across app restarts, reinstalls, and sync across devices.
class SettingsService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _darkMode = false;
  String _currency = 'INR (₹)';
  StreamSubscription? _sub;
  String? _listeningUid;

  bool get darkMode => _darkMode;
  String get currency => _currency;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('settings').doc('preferences');
  }

  /// Call once a user is logged in (e.g. from splash/dashboard) to start
  /// listening for real-time preference changes.
  void listen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == _listeningUid) return;
    _listeningUid = uid;
    _sub?.cancel();
    _sub = _doc?.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) {
        _darkMode = data['darkMode'] ?? false;
        _currency = data['currency'] ?? 'INR (₹)';
        notifyListeners();
      }
    });
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _doc?.set({'darkMode': value}, SetOptions(merge: true));
  }

  Future<void> setCurrency(String value) async {
    _currency = value;
    notifyListeners();
    await _doc?.set({'currency': value}, SetOptions(merge: true));
  }

  void reset() {
    _sub?.cancel();
    _listeningUid = null;
    _darkMode = false;
    _currency = 'INR (₹)';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
