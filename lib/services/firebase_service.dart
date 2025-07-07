import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timestamp_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // บันทึกการลงเวลา
  Future<void> saveTimestamp(TimestampModel timestamp) async {
    await _firestore.collection('timestamps').add(timestamp.toMap());
  }

  // ดึงประวัติการลงเวลา (แบบไม่ต้อง index)
  Stream<List<TimestampModel>> getTimestamps(String userId) {
    return _firestore
        .collection('timestamps')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          // Sort ใน client แทนที่จะใช้ orderBy
          var docs = snapshot.docs.toList();
          docs.sort((a, b) {
            Timestamp timestampA = a.data()['timestamp'] as Timestamp;
            Timestamp timestampB = b.data()['timestamp'] as Timestamp;
            return timestampB.compareTo(timestampA); // Descending order
          });

          // จำกัดแค่ 50 รายการ
          if (docs.length > 50) {
            docs = docs.take(50).toList();
          }

          return docs
              .map((doc) => TimestampModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
}
