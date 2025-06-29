import 'dart:async';
import 'dart:typed_data';

import 'package:e_hong_app/services/system_check_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart'; // เพิ่มการ import BluetoothService

class BluetoothController extends GetxController {
  final FlutterBlueClassic bluetooth = FlutterBlueClassic();
  final BluetoothService bluetoothService = BluetoothService();
  final SystemCheckService systemCheck = Get.put(SystemCheckService());

  var devices = <BluetoothDevice>[].obs;
  var selectedDevice = Rxn<BluetoothDevice>();
  var isConnecting = false.obs;
  var isConnected = false.obs;
  var isConnectResponseReceived = false.obs;
  var canActivate = false.obs;
  var lastCommandSent = 0.obs;
  var isWaitingResponse = false.obs;

  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<BluetoothDevice>? _scanSubscription;
  Timer? _responseTimeout;

  @override
  void onInit() {
    super.onInit();
    ensureBluetoothOnThenScan();
     _initializeSystem();
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _responseTimeout?.cancel();
    bluetoothService.disconnect(); // ใช้ service แทน
    super.onClose();
  }

   Future<void> _initializeSystem() async {
    bool systemReady = await systemCheck.ensureSystemReady();
    
    if (systemReady) {
      await ensureBluetoothOnThenScan();
    } else {
      systemCheck.showSystemNotReadyDialog();
    }
  }



  Future<void> ensureBluetoothOnThenScan() async {
    await requestPermissions();
    await startScan();
  }

  Future<void> startScan() async {
    // ตรวจสอบระบบก่อนสแกน
    if (!systemCheck.isSystemReady.value) {
      bool systemReady = await systemCheck.ensureSystemReady();
      if (!systemReady) {
        systemCheck.showSystemNotReadyDialog();
        return;
      }
    }

    isConnecting.value = true;
    devices.clear();
    await requestPermissions();

    try {
      bluetooth.startScan();
      _scanSubscription = bluetooth.scanResults.listen((device) {
        if (!devices.any((d) => d.address == device.address)) {
          devices.add(device);
        }
      });

      await Future.delayed(Duration(seconds: 5));
      await stopScan();
    } catch (e) {
      Get.snackbar(
        "❌ การสแกนล้มเหลว",
        "ไม่สามารถค้นหาอุปกรณ์ได้\nกรุณาตรวจสอบว่า Bluetooth เปิดอยู่",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> stopScan() async {
    bluetooth.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => !status.isGranted)) {
      Get.snackbar("Permission", "โปรดอนุญาตการเข้าถึง Bluetooth และ Location");
      return;
    }
  }

  // แก้ไข activateNow ให้ใช้ BluetoothService
  void activateNow() async {
    // ตรวจสอบระบบก่อนใช้งาน
    if (!systemCheck.isSystemReady.value) {
      bool systemReady = await systemCheck.ensureSystemReady();
      if (!systemReady) {
        systemCheck.showSystemNotReadyDialog();
        return;
      }
    }

    if (!bluetoothService.isConnected) {
      Get.snackbar(
        "ไม่ได้เชื่อมต่อ",
        "กรุณาเชื่อมต่ออุปกรณ์ก่อน",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!canActivate.value) {
      Get.snackbar(
        "ไม่สามารถใช้งานได้",
        "❌ กรุณารอให้ Activate Connect เสร็จสิ้นก่อน",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
   await   bluetoothService.sendCmdActivateNow();
      
    } catch (e) {
      print("Error sending Activate Now command: $e");
      Get.snackbar(
        "❌ เกิดข้อผิดพลาด",
        "ไม่สามารถส่งคำสั่ง Activate Now ได้: $e",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void resetWaitingState() {
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
  }

  Future<void> disconnect() async {
  try {
    // Cancel subscriptions ก่อน
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _responseTimeout?.cancel();
    
    // Reset states ทันที (UI จะอัปเดตทันที)
    isWaitingResponse.value = false;
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    lastCommandSent.value = 0;
    isConnected.value = false;
    selectedDevice.value = null;
    
    // Disconnect จาก service
    await bluetoothService.disconnect();
    
    // รอให้ UI อัปเดตก่อน แล้วค่อยเริ่ม scan อัตโนมัติ
    Future.delayed(Duration(milliseconds: 500), () {
      startScan();
    });
    
  } catch (e) {
    print("Error during disconnect: $e");
    
    // แม้เกิด error ก็ให้ reset state
    isConnected.value = false;
    selectedDevice.value = null;
    isConnectResponseReceived.value = false;
    canActivate.value = false;
  }
}


  void connectToDevice(BluetoothDevice device) async {
    // ตรวจสอบระบบก่อนเชื่อมต่อ
    if (!systemCheck.isSystemReady.value) {
      bool systemReady = await systemCheck.ensureSystemReady();
      if (!systemReady) {
        systemCheck.showSystemNotReadyDialog();
        return;
      }
    }

    try {
      isConnecting.value = true;
      await disconnect();
      
      await bluetoothService.connect(device);

      if (bluetoothService.isConnected) {
        selectedDevice.value = device;
        isConnected.value = true;
        isConnectResponseReceived.value = false;
        canActivate.value = false;


        Timer(Duration(seconds: 2), () {
          if (isConnected.value) {
            isConnectResponseReceived.value = true;
            canActivate.value = true;
          }
        });
        
      } else {
        throw "ไม่สามารถสร้างการเชื่อมต่อได้";
      }
    } catch (e) {
      print("Connection error: $e");
      isConnected.value = false;
      selectedDevice.value = null;
      isConnectResponseReceived.value = false;
      canActivate.value = false;

      String errorMessage = "ไม่สามารถเชื่อมต่อกับ ${device.name ?? 'อุปกรณ์'} ได้";
      
      // เพิ่มข้อความเฉพาะเมื่อเป็นปัญหาระบบ
      if (!systemCheck.isBluetoothEnabled.value) {
        errorMessage += "\n🔵 Bluetooth ไม่ได้เปิด";
      }

      Get.snackbar(
        "❌ เชื่อมต่อไม่สำเร็จ",
        errorMessage,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isConnecting.value = false;
    }
  }

}
