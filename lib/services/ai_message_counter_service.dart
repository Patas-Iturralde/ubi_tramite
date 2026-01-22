import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AiMessageCounterService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene el número de mensajes AI usados por el usuario actual
  static Future<int> getUsedMessages() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final doc = await _db.collection('ai_message_counters').doc(user.uid).get();
      if (doc.exists) {
        return (doc.data()?['count'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error al obtener contador de mensajes: $e');
      return 0;
    }
  }

  /// Incrementa el contador de mensajes AI del usuario actual
  static Future<void> incrementMessageCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('ai_message_counters').doc(user.uid).set({
        'count': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': user.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error al incrementar contador de mensajes: $e');
    }
  }

  /// Verifica si el usuario puede enviar más mensajes (1 mensaje gratis para no premium)
  static Future<bool> canSendMessage(bool isPremium) async {
    if (isPremium) return true; // Premium tiene mensajes ilimitados
    
    final usedMessages = await getUsedMessages();
    return usedMessages < 1; // Solo 1 mensaje gratis
  }

  /// Obtiene el número de mensajes restantes
  static Future<int> getRemainingMessages(bool isPremium) async {
    if (isPremium) return -1; // -1 significa ilimitado
    
    final usedMessages = await getUsedMessages();
    return (1 - usedMessages).clamp(0, 1);
  }
}

