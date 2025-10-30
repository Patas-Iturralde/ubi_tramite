import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/office_location.dart';

class FirestoreService {
  static CollectionReference<OfficeLocation> get _offices =>
      FirebaseFirestore.instance.collection('offices').withConverter<OfficeLocation>(
            fromFirestore: (snap, _) => OfficeLocation.fromJson(snap.data() ?? {}),
            toFirestore: (office, _) => office.toJson(),
          );

  static Future<List<OfficeLocation>> getAllOffices() async {
    final snapshot = await _offices.get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  static Future<bool> saveCustomOffice(OfficeLocation office) async {
    await _offices.doc(office.id).set(office);
    return true;
  }

  static Future<bool> deleteCustomOfficeByName(String name) async {
    final q = await _offices.where('name', isEqualTo: name).get();
    for (final doc in q.docs) {
      await doc.reference.delete();
    }
    return true;
  }

  static Future<bool> clearCustomOffices() async {
    final q = await _offices.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in q.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return true;
  }
}


