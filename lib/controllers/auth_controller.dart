// lib/controllers/auth_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/login_page.dart';
import '../services/firebase_service.dart';
import '../services/timestamp_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/local_storage_service.dart';
import '../services/system_check_service.dart'; // เพิ่มการ import
import '../models/user_model.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _firebaseService = FirebaseService();
  final _timestampService = TimestampService();
  Rxn<UserModel> currentUser = Rxn<UserModel>();
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
        Map<String, String?> sessionData =
            await LocalStorageService.getUserSession();
        String? userId = sessionData['userId'];

        if (userId != null) {
          // ดึงข้อมูลผู้ใช้จาก Firestore
          UserModel? user = await _firebaseService.getUserData(userId);

          if (user != null) {
            currentUser.value = user;
            _startSession();
            Get.offAllNamed('/home');
            return;
          }
        }
      }

      // ถ้าไม่มี session หรือข้อมูลไม่ถูกต้อง ให้ไปหน้า login
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

  // เปิดระบบทีละตัว
  Future<void> _enableSystemsSequentially(
    SystemCheckService systemCheck,
  ) async {
    // แสดง loading
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("กำลังตั้งค่าระบบ..."),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      // เปิด Bluetooth ถ้ายังปิด
      if (!systemCheck.isBluetoothEnabled.value) {
        await systemCheck.enableBluetooth();
        await Future.delayed(Duration(seconds: 1));
      }

      // เปิด GPS ถ้ายังปิด
      if (!systemCheck.isLocationEnabled.value) {
        await systemCheck.enableLocation();
        await Future.delayed(Duration(seconds: 1));
      }

      // ตรวจสอบสถานะสุดท้าย
      await systemCheck.checkSystemStatus();

      Get.back(); // ปิด loading dialog

      if (systemCheck.isSystemReady.value) {
        Get.snackbar(
          "✅ สำเร็จ",
          "ระบบพร้อมใช้งานแล้ว สามารถเข้าสู่ระบบได้",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          "⚠️ แจ้งเตือน",
          "กรุณาเปิดระบบที่เหลือด้วยตนเอง",
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.back(); // ปิด loading dialog
      Get.snackbar(
        "❌ ผิดพลาด",
        "เกิดข้อผิดพลาดในการตั้งค่าระบบ",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  Future<void> register({
    required String employeeNo,
    required String employeeName,
    required String password,
    required String company,
  }) async {
    // เช็คระบบก่อน register
    if (!await _checkSystemReady()) {
      return; // ถ้าระบบไม่พร้อมให้หยุด
    }

    try {
      isLoading.value = true;

      UserModel? user = await _firebaseService.registerEmployee(
        employeeNo: employeeNo,
        employeeName: employeeName,
        password: password,
        company: company,
      );

      if (user != null) {
        currentUser.value = user;

        // บันทึก session
        await LocalStorageService.saveUserSession(
          userId: user.id!,
          employeeNo: user.employeeNo,
          company: user.company,
        );

        // เริ่ม session timer
        _startSession();

        // Auto stamp time on successful login
        await _timestampService.stampTime(user);

        Get.snackbar(
          "สำเร็จ",
          "ลงทะเบียนสำเร็จ! ยินดีต้อนรับ ${user.employeeNo}",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );

        Get.offAllNamed('/home');
      }
    } catch (e) {
      Get.snackbar(
        "ลงทะเบียนล้มเหลว",
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login({
    required String employeeNo,
    required String password,
  }) async {
    // เช็คระบบก่อน login
    if (!await _checkSystemReady()) {
      return; // ถ้าระบบไม่พร้อมให้หยุด
    }

    try {
      isLoading.value = true;

      UserModel? user = await _firebaseService.loginEmployee(
        employeeNo: employeeNo,
        password: password,
      );

      if (user != null) {
        currentUser.value = user;

        // บันทึก session
        await LocalStorageService.saveUserSession(
          userId: user.id!,
          employeeNo: user.employeeNo,
          company: user.company,
        );

        // เริ่ม session timer
        _startSession();

        // Auto stamp time on successful login
        await _timestampService.stampTime(user);

        Get.snackbar(
          "เข้าสู่ระบบสำเร็จ",
          "ยินดีต้อนรับ ${user.employeeNo} (${user.company})",
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
        );

        Get.offAllNamed('/home');
      }
    } catch (e) {
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

      // Extend session เมื่อมีการใช้งาน
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
