import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Snippet {
  final String id;
  final String shortcut;
  final String content;

  Snippet({
    required this.id,
    required this.shortcut,
    required this.content,
  });

  factory Snippet.fromMap(String id, Map<String, dynamic> map) {
    return Snippet(
      id: id,
      shortcut: map['shortcut'] ?? '',
      content: map['content'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shortcut': shortcut,
      'content': content,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
