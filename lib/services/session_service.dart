// lib/services/session_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

class SessionService extends GetxController {
  static SessionService get to => Get.find();
  
  Timer? _sessionTimer;
  Timer? _warningTimer;
  Timer? _countdownTimer;
  static const int sessionTimeoutMinutes = 3; // 3 นาที
  static const int warningTimeSeconds = 30; // แจ้งเตือนก่อน 30 วินาที
  
  var remainingTime = 0.obs;
  var showWarning = false.obs;
  
  void startSession() {
    resetSession();
  }
  
  void resetSession() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _countdownTimer?.cancel();
    showWarning.value = false;
    remainingTime.value = sessionTimeoutMinutes * 60; // 3 นาทีในวินาที
    
    // ตั้งค่า Timer หลักสำหรับ Auto Logout
    // _sessionTimer = Timer(Duration(minutes: sessionTimeoutMinutes), () {
    _sessionTimer = Timer(Duration(days: sessionTimeoutMinutes), () {
      _performAutoLogout();
    });
    
    // ตั้งค่า Timer สำหรับแจ้งเตือนก่อน logout
    _warningTimer = Timer(
      Duration(days: sessionTimeoutMinutes) - Duration(seconds: warningTimeSeconds),
      // Duration(minutes: sessionTimeoutMinutes) - Duration(seconds: warningTimeSeconds),
      () {
        _showWarningDialog();
      }
    );
    
    // Timer สำหรับอัปเดตเวลาที่เหลือ
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingTime.value > 0) {
        remainingTime.value--;
      } else {
        timer.cancel();
      }
    });
    
    print("Session started - will logout after ${sessionTimeoutMinutes} minutes");
  }
  
  void extendSession() {
    print("Session extended");
    resetSession();
  }
  
  void _showWarningDialog() {
    showWarning.value = true;
    
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              "แจ้งเตือน",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "คุณจะถูกออกจากระบบในอีก ${warningTimeSeconds} วินาที",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              "คุณต้องการต่อการใช้งานหรือไม่?",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // ปิด dialog
              _performAutoLogout(); // logout ทันที
            },
            child: Text(
              "ออกจากระบบ",
              style: TextStyle(color: Colors.red[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // ปิด dialog
              extendSession(); // ต่อ session
              Get.snackbar(
                "ต่อการใช้งาน",
                "การใช้งานของคุณได้รับการต่ออายุแล้ว",
                backgroundColor: Colors.green.withOpacity(0.8),
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                duration: Duration(seconds: 2),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text("ต่อการใช้งาน"),
          ),
        ],
      ),
      barrierDismissible: false, // ไม่ให้ปิด dialog โดยกดข้างนอก
    );
  }
  
  void _performAutoLogout() {
    Get.back(); // ปิด dialog ถ้ามี
    
    // Import AuthController และเรียกใช้ logout
    try {
      final authController = Get.find<AuthController>();
      
      Get.snackbar(
        "หมดเวลาการใช้งาน",
        "คุณถูกออกจากระบบอัตโนมัติ กรุณาเข้าสู่ระบบใหม่",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: Duration(seconds: 4),
        icon: Icon(Icons.logout, color: Colors.white),
      );
      
      authController.logout();
    } catch (e) {
      print("Error during auto logout: $e");
      // Fallback - navigate to login directly
      Get.offAllNamed('/login');
    }
  }
  
  void stopSession() {
    _sessionTimer?.cancel();
    _warningTimer?.cancel();
    _countdownTimer?.cancel();
    showWarning.value = false;
    remainingTime.value = 0;
    print("Session stopped");
  }
  
  @override
  void onClose() {
    stopSession();
    super.onClose();
  }
  
  // Helper method สำหรับแสดงเวลาที่เหลือในรูปแบบ MM:SS
  String get formattedRemainingTime {
    int minutes = remainingTime.value ~/ 60;
    int seconds = remainingTime.value % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}