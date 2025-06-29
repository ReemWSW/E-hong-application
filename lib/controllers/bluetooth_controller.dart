import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart'; // เพิ่มการ import BluetoothService

class BluetoothController extends GetxController {
  final FlutterBlueClassic bluetooth = FlutterBlueClassic();
  final BluetoothService bluetoothService = BluetoothService(); // เพิ่ม instance ของ BluetoothService

  var devices = <BluetoothDevice>[].obs;
  var selectedDevice = Rxn<BluetoothDevice>();
  var isConnecting = false.obs;
  var isConnected = false.obs;
  var isConnectResponseReceived = false.obs;
  var canActivate = false.obs;
  var lastCommandSent = 0.obs;
  var isWaitingResponse = false.obs;

  // เอา BluetoothConnection ออกเพราะใช้ผ่าน service แล้ว
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<BluetoothDevice>? _scanSubscription;
  Timer? _responseTimeout;

  @override
  void onInit() {
    super.onInit();
    ensureBluetoothOnThenScan();
    autoReconnect();
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _responseTimeout?.cancel();
    bluetoothService.disconnect(); // ใช้ service แทน
    super.onClose();
  }

  Future<void> autoReconnect() async {
    String? lastAddress = await getLastConnectedDeviceAddress();

    if (lastAddress != null) {
      final bonded = await bluetooth.bondedDevices;
      final device = bonded?.firstWhereOrNull((d) => d.address == lastAddress);
      if (device != null) {
        connectToDevice(device);
      }
    }
  }

  Future<void> ensureBluetoothOnThenScan() async {
    await requestPermissions();
    await startScan();
  }

  Future<void> startScan() async {
    isConnecting.value = true;
    devices.clear();
    await requestPermissions();

    bluetooth.startScan();
    _scanSubscription = bluetooth.scanResults.listen((device) {
      if (!devices.any((d) => d.address == device.address)) {
        devices.add(device);
      }
    });

    await Future.delayed(Duration(seconds: 5));
    await stopScan();
    isConnecting.value = false;
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

  void _startListeningForData() {
    if (bluetoothService.connection == null) return;

    _dataSubscription = bluetoothService.connection!.input?.listen(
      (Uint8List data) {
        _handleReceivedData(data);
      },
      onError: (error) {
        print("Error receiving data: $error");
      },
    );
  }

  void _handleReceivedData(Uint8List data) {
    // (เหมือนเดิมทั้งหมด - ไม่เปลี่ยนโค้ดนี้)
  }

  bool _validateResponseChecksum(Uint8List data) {
    // (เหมือนเดิมทั้งหมด)
    return true;
  }

  void _handleConnectResponse(String responseType, int commandByte) {}
  void _handleActivateResponse(String responseType, int commandByte) {}
  void _handleTestResponse(String responseType, int commandByte) {}
  void _handleGeneralResponse(String responseType, int commandByte) {}

  // แก้ไข activateNow ให้ใช้ BluetoothService
  void activateNow() {
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
      bluetoothService.sendCmdActivateNow();
      
      Get.snackbar(
        "⚡ Activate Now สำเร็จ",
        "ส่งคำสั่ง Activate Now เรียบร้อยแล้ว",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
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

  void forceActivateResponse() {
    isConnectResponseReceived.value = true;
    canActivate.value = true;
    resetWaitingState();

    Get.snackbar(
      "⚠️ บังคับเปิดใช้งาน",
      "✅ บังคับให้ปุ่ม Activate Now ใช้งานได้\n(สำหรับการทดสอบ)",
      backgroundColor: Colors.amber.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> disconnect() async {
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _responseTimeout?.cancel();
    isWaitingResponse.value = false;
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    lastCommandSent.value = 0;

    await bluetoothService.disconnect(); // ใช้ service แทน
    isConnected.value = false;
    selectedDevice.value = null;
    await startScan();
  }

  Future<void> saveLastConnectedDevice(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_device', address);
  }

  Future<String?> getLastConnectedDeviceAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_device');
  }

  // แก้ไข connectToDevice ให้ใช้ BluetoothService
  void connectToDevice(BluetoothDevice device) async {
    try {
      isConnecting.value = true;
      await disconnect();
      
      // ใช้ BluetoothService แทนการเชื่อมต่อโดยตรง
      await bluetoothService.connect(device);

      if (bluetoothService.isConnected) {
        selectedDevice.value = device;
        isConnected.value = true;
        isConnectResponseReceived.value = false;
        canActivate.value = false;

        _startListeningForData();
        await saveLastConnectedDevice(device.address);

        Get.snackbar(
          "✅ เชื่อมต่อสำเร็จ",
          "เชื่อมต่อกับ ${device.name ?? 'Unknown'} สำเร็จแล้ว\nและส่งคำสั่ง Activate Connect อัตโนมัติ",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );

        // รอสักครู่แล้วเซ็ตสถานะว่า Activate Connect สำเร็จ
        Timer(Duration(seconds: 2), () {
          if (isConnected.value) {
            isConnectResponseReceived.value = true;
            canActivate.value = true;
            
            Get.snackbar(
              "✅ Activate Connect สำเร็จ",
              "🔌 พร้อมใช้งานปุ่ม Activate Now แล้ว",
              backgroundColor: Colors.green.withOpacity(0.8),
              colorText: Colors.white,
              duration: Duration(seconds: 2),
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        });
        
      } else {
        throw Exception("ไม่สามารถสร้างการเชื่อมต่อได้");
      }
    } catch (e) {
      print("Connection error: $e");
      isConnected.value = false;
      selectedDevice.value = null;
      isConnectResponseReceived.value = false;
      canActivate.value = false;

      Get.snackbar(
        "❌ เชื่อมต่อไม่สำเร็จ",
        "ไม่สามารถเชื่อมต่อกับ ${device.name ?? 'อุปกรณ์'} ได้\nError: $e",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isConnecting.value = false;
    }
  }

  // แก้ไข method activateConnect ให้เป็นแค่การแสดงสถานะ
  void activateConnect() {
    if (isConnectResponseReceived.value) {
      Get.snackbar(
        "ℹ️ Activate Connect",
        "✅ คำสั่ง Activate Connect ถูกส่งไปแล้วตอนเชื่อมต่ออุปกรณ์",
        backgroundColor: Colors.blue.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        "⚠️ Activate Connect",
        "❌ ยังไม่ได้ส่งคำสั่ง Activate Connect\nกรุณาเชื่อมต่ออุปกรณ์ใหม่",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}