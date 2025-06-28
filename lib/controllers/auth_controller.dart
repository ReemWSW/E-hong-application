// lib/controllers/auth_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../views/login_page.dart';
import '../services/firebase_service.dart';
import '../services/timestamp_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/local_storage_service.dart';
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
        Map<String, String?> sessionData = await LocalStorageService.getUserSession();
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

  Future<void> register({
    required String employeeNo,
    required String password,
    required String company,
  }) async {
    try {
      isLoading.value = true;
      
      UserModel? user = await _firebaseService.registerEmployee(
        employeeNo: employeeNo,
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
        String? stampError = await _timestampService.stampTime(user);
        
        if (stampError == null) {
          Get.snackbar(
            "เข้าสู่ระบบสำเร็จ",
            "ยินดีต้อนรับ ${user.employeeNo} (${user.company}) - บันทึกเวลาเข้างานสำเร็จ",
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          Get.snackbar(
            "เข้าสู่ระบบสำเร็จ",
            "ยินดีต้อนรับ ${user.employeeNo} (${user.company})\nแต่ไม่สามารถบันทึกเวลาได้: $stampError",
            backgroundColor: Colors.orange.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 4),
          );
        }
        
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