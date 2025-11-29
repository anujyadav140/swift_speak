import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DictionaryTerm {
  final String id;
  final String original;
  final String replacement;
  final bool isCorrection;

  DictionaryTerm({
    required this.id,
    required this.original,
    required this.replacement,
    this.isCorrection = false,
  });

  factory DictionaryTerm.fromMap(String id, Map<String, dynamic> map) {
    return DictionaryTerm(
      id: id,
      original: map['original'] ?? '',
      replacement: map['replacement'] ?? '',
      isCorrection: map['isCorrection'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'original': original,
      'replacement': replacement,
      'isCorrection': isCorrection,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

class DictionaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Stream<List<DictionaryTerm>> getTerms() {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('dictionary')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DictionaryTerm.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addTerm(String original, String replacement, {bool isCorrection = false}) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('dictionary')
        .add({
      'original': original,
      'replacement': replacement,
      'isCorrection': isCorrection,
      'userId': _userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTerm(String termId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('dictionary')
        .doc(termId)
        .delete();
  }
}
