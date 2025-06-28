// lib/services/local_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _userIdKey = 'current_user_id';
  static const String _employeeNoKey = 'employee_no';
  static const String _companyKey = 'company';

  // บันทึกข้อมูล session
  static Future<void> saveUserSession({
    required String userId,
    required String employeeNo,
    required String company,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_employeeNoKey, employeeNo);
    await prefs.setString(_companyKey, company);
  }

  // ดึงข้อมูล session
  static Future<Map<String, String?>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_userIdKey),
      'employeeNo': prefs.getString(_employeeNoKey),
      'company': prefs.getString(_companyKey),
    };
  }

  // ลบข้อมูล session
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_employeeNoKey);
    await prefs.remove(_companyKey);
  }

  // ตรวจสอบว่ามี session หรือไม่
  static Future<bool> hasUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userIdKey);
  }
}