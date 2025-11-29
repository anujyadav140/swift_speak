import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/snippet.dart';

class SnippetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  Stream<List<Snippet>> getSnippets() {
    if (_userId == null) {
      debugPrint("SnippetService: No user logged in.");
      return Stream.value([]);
    }

    debugPrint("SnippetService: Listening for snippets for user $_userId");

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('snippets')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("SnippetService: Fetched ${snapshot.docs.length} snippets from Firestore.");
      final snippets = snapshot.docs
          .map((doc) => Snippet.fromMap(doc.id, doc.data()))
          .toList();
      
      for (var s in snippets) {
        debugPrint("SnippetService: Loaded '${s.shortcut}' -> '${s.content}'");
      }
      return snippets;
    });
  }

  Future<void> addSnippet(String shortcut, String content) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('snippets')
        .add({
      'shortcut': shortcut,
      'content': content,
      'userId': _userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSnippet(String id, String shortcut, String content) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('snippets')
        .doc(id)
        .update({
      'shortcut': shortcut,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSnippet(String id) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('snippets')
        .doc(id)
        .delete();
  }
}
