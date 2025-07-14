// lib/controllers/auth_controller.dart
import 'package:e_hong_app/services/ehong_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/login_page.dart';
import '../services/timestamp_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/local_storage_service.dart';
import '../services/system_check_service.dart'; // เพิ่มการ import
import '../services/expire_check_service.dart';
import '../models/user_model.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _ehongAuthService = EhongAuthService();
  final _timestampService = TimestampService();
  final _expireCheckService = ExpireCheckService();
  Rxn<EhongUserModel> currentUser = Rxn<EhongUserModel>();
  var isLoading = false.obs;

  @override
  void onReady() async {
    super.onReady();

    // Request location permissions on app start
    await LocationService.requestPermissions();

    // ตรวจสอบว่ามี session เก่าหรือไม่
    await _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      bool hasSession = await LocalStorageService.hasUserSession();

      if (hasSession) {
        final sessionData = await LocalStorageService.getUserSession();

        // แปลง session data จาก Map<String, String?> → EhongUserModel
        final user = EhongUserModel.fromMap(sessionData);
        currentUser.value = user;

        _startSession();
        Get.offAllNamed('/home');
        return;
      }

      // ไม่มี session
      await LocalStorageService.clearUserSession();
      Get.offAll(() => LoginPage());
    } catch (e) {
      print('Error checking session: $e');
      await LocalStorageService.clearUserSession();
      Get.offAll(() => LoginPage());
    }
  }

  // เพิ่ม method สำหรับเช็คระบบ
  Future<bool> _checkSystemReady() async {
    try {
      // หา SystemCheckService หรือสร้างใหม่
      SystemCheckService systemCheck;
      try {
        systemCheck = Get.find<SystemCheckService>();
      } catch (e) {
        systemCheck = Get.put(SystemCheckService());
      }

      // เช็คสถานะระบบ
      await systemCheck.checkSystemStatus();

      // ถ้าระบบไม่พร้อม
      if (!systemCheck.isSystemReady.value) {
        _showSystemRequiredDialog(systemCheck);
        return false;
      }

      return true;
    } catch (e) {
      print("Error checking system: $e");
      return false;
    }
  }

  // แสดง dialog เตือนแอปหมดอายุ
  void _showExpiredDialog() {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red[600]),
              SizedBox(width: 8),
              Text("แอปพลิเคชันหมดอายุ"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "แอปพลิเคชันนี้ได้หมดอายุการใช้งานแล้ว",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "กรุณาต่ออายุการใช้งาน",
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text("ปิด"),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  // แสดง dialog เตือนระบบไม่พร้อม
  void _showSystemRequiredDialog(SystemCheckService systemCheck) {
    List<String> missingServices = [];

    if (!systemCheck.isBluetoothEnabled.value) {
      missingServices.add("🔵 Bluetooth");
    }

    if (!systemCheck.isLocationEnabled.value) {
      missingServices.add("📍 GPS/Location");
    }

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600]),
              SizedBox(width: 8),
              Text("ระบบไม่พร้อม"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "กรุณาเปิดระบบดังต่อไปนี้ก่อนเข้าสู่ระบบ:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ...missingServices.map(
                (service) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, color: Colors.red[600], size: 20),
                      SizedBox(width: 8),
                      Text(service),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "⚠️ จำเป็นต้องเปิดระบบเหล่านี้เพื่อใช้งานแอป",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text("ปิด")),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> login({
    required String employeeNo,
    required String password,
  }) async {
    if (!await _checkSystemReady()) return;

    try {
      isLoading.value = true;

      // Check if app is expired before proceeding with login
      final isNotExpired = await _expireCheckService.checkExpiration();
      if (!isNotExpired) {
        _showExpiredDialog();
        return;
      }

      final userMap = await _ehongAuthService.login(
        username: employeeNo,
        password: password,
      );

      final user = EhongUserModel.fromMap(userMap);
      currentUser.value = user;

      // บันทึก session
      await LocalStorageService.saveUserSession(
        userId: user.empId,
        employeeNo: user.barcode,
        company: user.brId,
      );

      _startSession();

      await _timestampService.stampTime(user); // ← เปลี่ยนให้รับ EhongUserModel

      Get.snackbar(
        "เข้าสู่ระบบสำเร็จ",
        "ยินดีต้อนรับ ${user.fullName} (${user.brId})",
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offAllNamed('/home');
    } catch (e) {
      if (kDebugMode) {
        print("Login error: $e");
      }
      Get.snackbar(
        "เข้าสู่ระบบล้มเหลว",
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    // หยุด session timer
    _stopSession();

    // ลบ session จาก local storage
    await LocalStorageService.clearUserSession();

    // ลบข้อมูล user
    currentUser.value = null;

    // กลับไปหน้า login
    Get.offAll(() => LoginPage());
  }

  Future<void> manualStampTime() async {
    if (currentUser.value == null) {
      Get.snackbar(
        "ข้อผิดพลาด",
        "กรุณาเข้าสู่ระบบก่อน",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isLoading.value = true;
      _extendSession();

      String? error = await _timestampService.stampTime(currentUser.value!);

      if (error == null) {
        Get.snackbar(
          "สำเร็จ",
          "บันทึกเวลาสำเร็จ",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          "ไม่สำเร็จ",
          error,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // Methods สำหรับจัดการ Session
  void _startSession() {
    try {
      final sessionService = Get.find<SessionService>();
      sessionService.startSession();
    } catch (e) {
      // ถ้ายังไม่มี SessionService ให้สร้างใหม่
      Get.put(SessionService());
      final sessionService = Get.find<SessionService>();
      sessionService.startSession();
    }
  }

  void _extendSession() {
    try {
      final sessionService = Get.find<SessionService>();
      sessionService.extendSession();
    } catch (e) {
      print("SessionService not found: $e");
    }
  }

  void _stopSession() {
    try {
      final sessionService = Get.find<SessionService>();
      sessionService.stopSession();
    } catch (e) {
      print("SessionService not found: $e");
    }
  }

  // Method สำหรับ extend session จาก UI
  void extendUserSession() {
    _extendSession();
    Get.snackbar(
      "ต่อการใช้งาน",
      "การใช้งานของคุณได้รับการต่ออายุแล้ว",
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
    );
  }
}
