import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class SystemCheckService extends GetxController {
  var isBluetoothEnabled = false.obs;
  var isLocationEnabled = false.obs;
  var isSystemReady = false.obs;
  var isCheckingOnStart = false.obs; // เพิ่มสำหรับตรวจสอบตอนเริ่มต้น
  
  Timer? _statusCheckTimer;
  
  @override
  void onInit() {
    super.onInit();
    // ตรวจสอบและขอเปิดระบบทันทีตอนเริ่มต้น
    _checkSystemOnAppStart();
  }
  
  @override
  void onClose() {
    _statusCheckTimer?.cancel();
    super.onClose();
  }
  
  // ตรวจสอบระบบตอนเริ่มต้นแอป
  Future<void> _checkSystemOnAppStart() async {
    isCheckingOnStart.value = true;
    
    // รอสักครู่ให้แอปโหลดเสร็จ
    await Future.delayed(Duration(milliseconds: 500));
    
    await checkSystemStatus();
    
    // ถ้าระบบไม่พร้อม ให้แสดง dialog และขอเปิด
    if (!isSystemReady.value) {
      await _showStartupSystemDialog();
    }
    
    isCheckingOnStart.value = false;
    
    // เริ่มตรวจสอบแบบ real-time หลังจากเช็คครั้งแรกเสร็จ
    startStatusMonitoring();
  }
  
  // แสดง dialog ตอนเริ่มต้นแอป
  Future<void> _showStartupSystemDialog() async {
    List<String> missingServices = [];
    
    if (!isBluetoothEnabled.value) {
      missingServices.add("🔵 Bluetooth");
    }
    
    if (!isLocationEnabled.value) {
      missingServices.add("📍 GPS/Location");
    }
    
    if (missingServices.isEmpty) return;
    
    await Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // ไม่ให้ปิด dialog ด้วย back button
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.settings, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text("ตั้งค่าระบบ"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "แอปต้องการเปิดระบบต่อไปนี้:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              ...missingServices.map((service) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.arrow_right, color: Colors.blue[600], size: 20),
                    SizedBox(width: 8),
                    Text(service),
                  ],
                ),
              )),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ระบบจะขอสิทธิ์และเปิดการตั้งค่าให้อัตโนมัติ",
                  style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await _enableSystemsSequentially();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: Text("เปิดระบบ"),
            ),
          ],
        ),
      ),
      barrierDismissible: false, // ไม่ให้ปิด dialog ด้วยการกดข้างนอก
    );
  }
  
  // เปิดระบบทีละตัวตามลำดับ
  Future<void> _enableSystemsSequentially() async {
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
      if (!isBluetoothEnabled.value) {
        await enableBluetooth();
        await Future.delayed(Duration(seconds: 1));
      }
      
      // เปิด GPS ถ้ายังปิด
      if (!isLocationEnabled.value) {
        await enableLocation();
        await Future.delayed(Duration(seconds: 1));
      }
      
      // ตรวจสอบสถานะสุดท้าย
      await checkSystemStatus();
      
      Get.back(); // ปิด loading dialog
      
      // แสดงผลลัพธ์
      if (isSystemReady.value) {
        Get.snackbar(
          "✅ สำเร็จ",
          "ระบบพร้อมใช้งานแล้ว",
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
  
  // เริ่มตรวจสอบสถานะระบบแบบ real-time
  void startStatusMonitoring() {
    // ตรวจสอบทุก 5 วินาที (ลดลงจาก 3 วินาที)
    _statusCheckTimer = Timer.periodic(Duration(seconds: 5), (_) {
      checkSystemStatus();
    });
  }
  
  // ตรวจสอบสถานะ Bluetooth และ GPS
  Future<void> checkSystemStatus() async {
    await checkBluetoothStatus();
    await checkLocationStatus();
    
    // อัปเดตสถานะระบบโดยรวม
    isSystemReady.value = isBluetoothEnabled.value && isLocationEnabled.value;
  }
  
  // ตรวจสอบสถานะ Bluetooth
  Future<void> checkBluetoothStatus() async {
    try {
      ServiceStatus status = await Permission.bluetooth.serviceStatus;
      isBluetoothEnabled.value = status == ServiceStatus.enabled;
    } catch (e) {
      print("Error checking Bluetooth status: $e");
      isBluetoothEnabled.value = false;
    }
  }
  
  // ตรวจสอบสถานะ GPS
  Future<void> checkLocationStatus() async {
    try {
      ServiceStatus status = await Permission.location.serviceStatus;
      isLocationEnabled.value = status == ServiceStatus.enabled;
    } catch (e) {
      print("Error checking Location status: $e");
      isLocationEnabled.value = false;
    }
  }
  
  // เปิด Bluetooth
  Future<bool> enableBluetooth() async {
    try {
      PermissionStatus status = await Permission.bluetooth.request();
      
      if (status.isDenied || status.isPermanentlyDenied) {
        await openAppSettings();
        await Future.delayed(Duration(seconds: 2));
      }
      
      await checkBluetoothStatus();
      return isBluetoothEnabled.value;
    } catch (e) {
      print("Error enabling Bluetooth: $e");
      return false;
    }
  }
  
  // เปิด GPS
  Future<bool> enableLocation() async {
    try {
      PermissionStatus status = await Permission.location.request();
      
      if (status.isDenied || status.isPermanentlyDenied) {
        await openAppSettings();
        await Future.delayed(Duration(seconds: 2));
      }
      
      await checkLocationStatus();
      return isLocationEnabled.value;
    } catch (e) {
      print("Error enabling Location: $e");
      return false;
    }
  }
  
  // ตรวจสอบและขอให้เปิดระบบที่จำเป็น (สำหรับเรียกจากที่อื่น)
  Future<bool> ensureSystemReady() async {
    await checkSystemStatus();
    
    // if (!isSystemReady.value) {
    //   await _enableSystemsSequentially();
    // }
    
    return isSystemReady.value;
  }
  
  // แสดง dialog เตือนเมื่อระบบไม่พร้อม (สำหรับเรียกจากที่อื่น)
  void showSystemNotReadyDialog() {
    List<String> missingServices = [];
    
    if (!isBluetoothEnabled.value) {
      missingServices.add("🔵 Bluetooth");
    }
    
    if (!isLocationEnabled.value) {
      missingServices.add("📍 GPS/Location");
    }
    
    if (missingServices.isEmpty) return;
    
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text("ระบบไม่พร้อม"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "กรุณาเปิดระบบดังต่อไปนี้:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            ...missingServices.map((service) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text("กรุณาเปิด $service"),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("ปิด"),
          ),
        ],
      ),
    );
  }
}