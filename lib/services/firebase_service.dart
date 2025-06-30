// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/timestamp_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ลงทะเบียนพนักงานใหม่
  Future<UserModel?> registerEmployee({
  required String employeeNo,
 required String employeeName, // เพิ่มพารามิเตอร์ชื่อพนักงาน
  required String password,
  required String company,
}) async {
  try {
    // ตรวจสอบว่า employeeNo ซ้ำหรือไม่
    final existingEmployee = await _firestore
        .collection('employees')
        .where('employeeNo', isEqualTo: employeeNo)
        .limit(1)
        .get();

    if (existingEmployee.docs.isNotEmpty) {
      throw 'หมายเลขพนักงาน $employeeNo มีอยู่ในระบบแล้ว';
    }

    // สร้าง UserModel ใหม่
    UserModel newUser = UserModel.create(
      employeeNo: employeeNo,
      employeeName: employeeName,
      company: company,
      password: password,
    );

    // บันทึกลง Firestore
    DocumentReference docRef = await _firestore
        .collection('employees')
        .add(newUser.toMap());

    // ส่งกลับ UserModel พร้อม ID
    return UserModel(
      id: docRef.id,
      employeeNo: newUser.employeeNo,
      employeeName: newUser.employeeName,
      company: newUser.company,
      passwordHash: newUser.passwordHash,
      lastLogin: newUser.lastLogin,
    );
  } catch (e) {
    throw e.toString();
  }
}

  // เข้าสู่ระบบ (ใช้เฉพาะ employeeNo + password)
  Future<UserModel?> loginEmployee({
    required String employeeNo,
    required String password,
  }) async {
    try {
      // ค้นหาพนักงานในฐานข้อมูล (ใช้เฉพาะ employeeNo)
      final querySnapshot = await _firestore
          .collection('employees')
          .where('employeeNo', isEqualTo: employeeNo)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'ไม่พบพนักงานหมายเลข $employeeNo';
      }

      // ตรวจสอบว่ามีมากกว่า 1 พนักงานหรือไม่ (เผื่อมี employeeNo ซ้ำข้ามบริษัท)
      if (querySnapshot.docs.length > 1) {
        // ถ้ามีหลายคน ให้แสดงรายชื่อบริษัท
        List<String> companies = querySnapshot.docs
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['company'] as String,
            )
            .toSet()
            .toList();

        throw 'พบพนักงานหมายเลข $employeeNo ในหลายบริษัท: ${companies.join(", ")}\nกรุณาติดต่อผู้ดูแลระบบ';
      }

      // ได้ข้อมูลพนักงาน
      DocumentSnapshot doc = querySnapshot.docs.first;
      UserModel user = UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );

      // ตรวจสอบรหัสผ่าน
      if (!user.verifyPassword(password)) {
        throw 'รหัสผ่านไม่ถูกต้อง';
      }

      // อัปเดต last login
      UserModel updatedUser = user.copyWithLastLogin();
      await _firestore.collection('employees').doc(user.id!).update({
        'lastLogin': Timestamp.fromDate(DateTime.now()),
      });

      return updatedUser;
    } catch (e) {
      // ตรวจสอบว่า error เป็น String ที่เรา throw เองหรือไม่
      if (e is String) {
        throw e; // throw error message โดยตรง
      }

      // ถ้าเป็น error อื่นๆ ให้แปลงเป็นข้อความที่เข้าใจง่าย
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // เอาคำว่า "Exception: " ออก
      }

      throw errorMessage;
    }
  }

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

  // ดึงข้อมูลพนักงาน
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('employees')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}
