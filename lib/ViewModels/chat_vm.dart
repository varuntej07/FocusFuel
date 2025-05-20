import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatViewModel extends ChangeNotifier {
  final String userId;

  ChatViewModel({required this.userId});

  Stream<QuerySnapshot> getMessageStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('messages')
        .add({
      'content': text.trim(),
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    notifyListeners();
  }
}