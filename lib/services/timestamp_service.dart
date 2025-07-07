import 'package:geolocator/geolocator.dart';
import '../models/user_model.dart';
import '../models/timestamp_model.dart';
import 'firebase_service.dart';
import 'location_service.dart';

class TimestampService {
  final FirebaseService _firebaseService = FirebaseService();

  Future<String?> stampTime(EhongUserModel user) async {
    try {
      // Get current location
      Position? position = await LocationService.getCurrentLocation();
      if (position == null) {
        return 'ไม่สามารถระบุตำแหน่งได้ กรุณาเปิด GPS และอนุญาตการเข้าถึงตำแหน่ง';
      }

      // สร้าง timestamp record โดยใช้ข้อมูลจาก EhongUserModel
      TimestampModel timestamp = TimestampModel(
        userId: user.empId, // ใช้ empId หรือ barcode แทน userId
        employeeNo: user.barcode,
        company: user.brId, // ใช้ brId แทนชื่อบริษัท
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );

      await _firebaseService.saveTimestamp(timestamp);
      return null; // Success
    } catch (e) {
      return 'เกิดข้อผิดพลาด: $e';
    }
  }

  Stream<List<TimestampModel>> getTimestamps(String userId) {
    return _firebaseService.getTimestamps(userId);
  }
}
