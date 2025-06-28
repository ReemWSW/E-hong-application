// lib/services/timestamp_service.dart
import 'package:geolocator/geolocator.dart';
import '../models/timestamp_model.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';
import 'location_service.dart';

class TimestampService {
  final FirebaseService _firebaseService = FirebaseService();

  Future<String?> stampTime(UserModel user) async {
    try {
      // Get current location
      Position? position = await LocationService.getCurrentLocation();
      if (position == null) {
        return 'ไม่สามารถระบุตำแหน่งได้ กรุณาเปิด GPS และอนุญาตการเข้าถึงตำแหน่ง';
      }

      // Create timestamp record
      TimestampModel timestamp = TimestampModel(
        userId: user.id!,
        employeeNo: user.employeeNo,
        company: user.company,
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