import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Uploads receipt photos to Firebase Storage. Previously firebase_storage
/// was a declared dependency that was never actually used anywhere in the
/// app — receipt photos were captured for OCR and then thrown away instead
/// of being saved against the expense record.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads [file] to users/{uid}/receipts/{timestamp}.jpg and returns a
  /// public download URL to store on the Expense document.
  Future<String?> uploadReceipt(File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('users/$uid/receipts/$ts.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
