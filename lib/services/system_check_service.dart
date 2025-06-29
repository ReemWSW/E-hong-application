import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class SystemCheckService extends GetxController {
  var isBluetoothEnabled = false.obs;
  var isLocationEnabled = false.obs;
  var isSystemReady = false.obs;
  
  Timer? _statusCheckTimer;
  
  @override
  void onInit() {
    super.onInit();
    startStatusMonitoring();
  }
  
  @override
  void onClose() {
    _statusCheckTimer?.cancel();
    super.onClose();
  }
  
  // เริ่มตรวจสอบสถานะระบบแบบ real-time
  void startStatusMonitoring() {
    // ตรวจสอบทันทีเมื่อเริ่มต้น
    checkSystemStatus();
    
    // ตรวจสอบทุก 3 วินาที
    _statusCheckTimer = Timer.periodic(Duration(seconds: 3), (_) {
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
      // ขอ permission และเปิด Bluetooth
      PermissionStatus status = await Permission.bluetooth.request();
      
      if (status.isDenied || status.isPermanentlyDenied) {
        await openAppSettings();
      }
      
      // ตรวจสอบใหม่
      await checkBluetoothStatus();
      
      if (isBluetoothEnabled.value) {
        Get.snackbar(
          "✅ สำเร็จ",
          "เปิด Bluetooth เรียบร้อยแล้ว",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          "❌ ไม่สำเร็จ",
          "กรุณาเปิด Bluetooth ในการตั้งค่า",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
      
      return isBluetoothEnabled.value;
    } catch (e) {
      print("Error enabling Bluetooth: $e");
      return false;
    }
  }
  
  // เปิด GPS
  Future<bool> enableLocation() async {
    try {
      // ขอ permission และเปิด Location
      PermissionStatus status = await Permission.location.request();
      
      if (status.isDenied || status.isPermanentlyDenied) {
        await openAppSettings();
      }
      
      // ตรวจสอบใหม่
      await checkLocationStatus();
      
      if (isLocationEnabled.value) {
        Get.snackbar(
          "✅ สำเร็จ",
          "เปิด GPS เรียบร้อยแล้ว",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          "❌ ไม่สำเร็จ",
          "กรุณาเปิด GPS ในการตั้งค่า",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
      
      return isLocationEnabled.value;
    } catch (e) {
      print("Error enabling Location: $e");
      return false;
    }
  }
  
  // ตรวจสอบและขอให้เปิดระบบที่จำเป็น
  Future<bool> ensureSystemReady() async {
    await checkSystemStatus();
    
    if (!isBluetoothEnabled.value) {
      await enableBluetooth();
    }
    
    if (!isLocationEnabled.value) {
      await enableLocation();
    }
    
    // ตรวจสอบอีกครั้งหลังจากพยายามเปิด
    await checkSystemStatus();
    
    return isSystemReady.value;
  }
  
  // แสดง dialog เตือนเมื่อระบบไม่พร้อม
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
              child: Text("• $service"),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("ปิด"),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await ensureSystemReady();
            },
            child: Text("เปิดระบบ"),
          ),
        ],
      ),
    );
  }
}