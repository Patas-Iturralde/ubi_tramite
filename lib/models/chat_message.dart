import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String text;
  final DateTime timestamp;
  final bool isAdmin;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.text,
    required this.timestamp,
    this.isAdmin = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isAdmin': isAdmin,
    };
  }
}

