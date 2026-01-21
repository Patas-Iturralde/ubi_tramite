import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_message.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Colección de mensajes de chat
  static CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      _db.collection('chat_messages');

  // Enviar un mensaje
  static Future<void> sendMessage(String text, {bool isAdmin = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final message = ChatMessage(
      id: '', // Se generará automáticamente
      userId: user.uid,
      userName: user.displayName ?? 'Usuario',
      userEmail: user.email ?? '',
      text: text,
      timestamp: DateTime.now(),
      isAdmin: isAdmin,
    );

    await _messagesCollection.add(message.toFirestore());
  }

  // Obtener stream de mensajes (tiempo real)
  static Stream<List<ChatMessage>> getMessagesStream() {
    return _messagesCollection
        .orderBy('timestamp', descending: false)
        .limitToLast(100) // Limitar a los últimos 100 mensajes
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
    });
  }

  // Marcar mensajes como leídos (opcional, para futuras mejoras)
  static Future<void> markAsRead(String messageId) async {
    // Implementación futura si se necesita
  }

  // Eliminar un mensaje (solo para admins)
  static Future<void> deleteMessage(String messageId) async {
    await _messagesCollection.doc(messageId).delete();
  }
}

