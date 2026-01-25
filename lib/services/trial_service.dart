import 'package:cloud_firestore/cloud_firestore.dart';

class TrialService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int trialDays = 30;

  /// Obtiene la fecha de registro del usuario desde Firestore
  static Future<DateTime?> getUserRegistrationDate(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null) return null;
      
      // createdAt puede ser un Timestamp o null
      final createdAt = data['createdAt'];
      if (createdAt == null) return null;
      
      if (createdAt is Timestamp) {
        return createdAt.toDate();
      }
      
      return null;
    } catch (e) {
      print('Error al obtener fecha de registro: $e');
      return null;
    }
  }

  /// Calcula los días restantes de la prueba gratuita
  /// Retorna null si no hay fecha de registro o si ya expiró
  static Future<int?> getRemainingTrialDays(String uid) async {
    final registrationDate = await getUserRegistrationDate(uid);
    if (registrationDate == null) return null;
    
    final now = DateTime.now();
    final trialEndDate = registrationDate.add(Duration(days: trialDays));
    final difference = trialEndDate.difference(now);
    
    if (difference.isNegative) {
      // La prueba ya expiró
      return 0;
    }
    
    return difference.inDays + 1; // +1 para incluir el día actual si aún no ha pasado
  }

  /// Verifica si el usuario está en período de prueba gratuita
  static Future<bool> isInTrialPeriod(String uid) async {
    final remainingDays = await getRemainingTrialDays(uid);
    if (remainingDays == null) return false;
    return remainingDays > 0;
  }

  /// Obtiene un stream de los días restantes de prueba
  static Stream<int?> getRemainingTrialDaysStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null) return null;
      
      final createdAt = data['createdAt'];
      if (createdAt == null) return null;
      
      DateTime? registrationDate;
      if (createdAt is Timestamp) {
        registrationDate = createdAt.toDate();
      }
      
      if (registrationDate == null) return null;
      
      final now = DateTime.now();
      final trialEndDate = registrationDate.add(Duration(days: trialDays));
      final difference = trialEndDate.difference(now);
      
      if (difference.isNegative) {
        return 0;
      }
      
      return difference.inDays + 1;
    });
  }
}

