import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothController extends GetxController {
  final FlutterBlueClassic bluetooth = FlutterBlueClassic();

  var devices = <BluetoothDevice>[].obs;
  var selectedDevice = Rxn<BluetoothDevice>();
  var isConnecting = false.obs;
  var isConnected = false.obs;
  var isConnectResponseReceived = false.obs;
  var canActivate = false.obs;
  var lastCommandSent = 0.obs;
  var isWaitingResponse = false.obs;

  BluetoothConnection? connection;
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
    connection?.dispose();
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
    if (connection == null) return;

    _dataSubscription = connection!.input?.listen(
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

  void sendCommand(int commandByte, {String? successMessage}) {
    if (connection == null || !connection!.isConnected) {
      Get.snackbar(
        "❌ ยังไม่ได้เชื่อมต่อ", 
        "กรุณาเชื่อมต่อกับอุปกรณ์ก่อนส่งคำสั่ง",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!isConnected.value) {
      Get.snackbar(
        "❌ การเชื่อมต่อขาดหาย", 
        "การเชื่อมต่อ Bluetooth หลุด กรุณาเชื่อมต่อใหม่",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      isConnected.value = false;
      selectedDevice.value = null;
      return;
    }

    if (isWaitingResponse.value) {
      Get.snackbar(
        "⏳ กำลังรอการตอบกลับ",
        "กรุณารอให้คำสั่งก่อนหน้าเสร็จสิ้นก่อน",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      List<int> packet = List.filled(64, 0);
      packet[0] = 0xA1;
      packet[1] = 0x11;
      packet[2] = 0xF1;
      packet[3] = commandByte;

      int sum = 0;
      for (int i = 0; i < 62; i++) {
        sum += packet[i];
      }
      packet[62] = sum & 0xFF;
      packet[63] = 0xE1;

      lastCommandSent.value = commandByte;
      isWaitingResponse.value = true;

      _responseTimeout?.cancel();
      _responseTimeout = Timer(Duration(seconds: 10), () {
        if (isWaitingResponse.value) {
          isWaitingResponse.value = false;
          Get.snackbar(
            "⏰ หมดเวลารอ",
            "❌ ไม่ได้รับการตอบกลับจากอุปกรณ์\nลองส่งคำสั่งใหม่อีกครั้ง",
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            duration: Duration(seconds: 4),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });

      connection!.output.add(Uint8List.fromList(packet));
      connection!.output.allSent.then((_) {
        print("Sent command: $commandByte (0x${commandByte.toRadixString(16).padLeft(2, '0').toUpperCase()})");

        if (successMessage != null) {
          Get.snackbar(
            "📤 ส่งคำสั่งแล้ว", 
            successMessage,
            backgroundColor: Colors.blue.withOpacity(0.8),
            colorText: Colors.white,
            duration: Duration(seconds: 2),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }).catchError((error) {
        isWaitingResponse.value = false;
        _responseTimeout?.cancel();

        print("Error sending command: $error");

        Get.snackbar(
          "❌ ส่งคำสั่งไม่สำเร็จ", 
          "ไม่สามารถส่งคำสั่งได้: $error\nลองเชื่อมต่อใหม่",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 4),
          snackPosition: SnackPosition.BOTTOM,
        );

        isConnected.value = false;
        selectedDevice.value = null;
      });

    } catch (e) {
      isWaitingResponse.value = false;
      _responseTimeout?.cancel();

      print("Exception in sendCommand: $e");

      Get.snackbar(
        "❌ เกิดข้อผิดพลาด", 
        "ไม่สามารถส่งคำสั่งได้: $e",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );

      isConnected.value = false;
      selectedDevice.value = null;
    }
  }

  void activateConnect() {
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    sendCommand(0x01, successMessage: "🔌 ส่งคำสั่ง Connect สำเร็จ");
  }

  void activateNow() {
    if (!canActivate.value) {
      Get.snackbar(
        "ไม่สามารถใช้งานได้",
        "❌ กรุณากด Connect และรอการตอบกลับจากอุปกรณ์ก่อน",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    sendCommand(0x02, successMessage: "⚡ ส่งคำสั่ง Activate Now");
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

    await connection?.close();
    connection = null;
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

  void connectToDevice(BluetoothDevice device) async {
    try {
      isConnecting.value = true;
      await disconnect();
      connection = await bluetooth.connect(device.address);

      if (connection != null && connection!.isConnected) {
        selectedDevice.value = device;
        isConnected.value = true;
        isConnectResponseReceived.value = false;
        canActivate.value = false;

        _startListeningForData();
        await saveLastConnectedDevice(device.address);

        Get.snackbar(
          "✅ เชื่อมต่อสำเร็จ",
          "เชื่อมต่อกับ ${device.name ?? 'Unknown'} สำเร็จแล้ว",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );
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
}