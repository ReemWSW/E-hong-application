import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';

class BluetoothController extends GetxController {
  final bluetoothService = BluetoothService();

  var devices = <BluetoothDevice>[].obs;
  var selectedDevice = Rxn<BluetoothDevice>();
  var isConnecting = false.obs;
  var isConnected = false.obs;
  var isConnectResponseReceived = false.obs; // เพิ่มตัวแปรสำหรับตรวจสอบการตอบกลับ
  var canActivate = false.obs; // เพิ่มตัวแปรสำหรับควบคุมการเปิดใช้งานปุ่ม Activate

  StreamSubscription<Uint8List>? _dataSubscription;

  @override
  void onInit() {
    super.onInit();
    ensureBluetoothOnThenScan();
    autoReconnect();
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    super.onClose();
  }

  Future<void> autoReconnect() async {
    String? lastAddress = await getLastConnectedDeviceAddress();

    if (lastAddress != null) {
      List<BluetoothDevice> bonded = await bluetoothService.getBondedDevices();

      final device = bonded.firstWhereOrNull((d) => d.address == lastAddress);
      if (device != null) {
        connectToDevice(device);
      }
    }
  }

  Future<void> ensureBluetoothOnThenScan() async {
    await requestPermissions(); // สำคัญมาก!

    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;

    if (isEnabled == null || !isEnabled) {
      try {
        await FlutterBluetoothSerial.instance.requestEnable();
      } catch (e) {
        Get.snackbar("Error", "ไม่สามารถเปิด Bluetooth ได้: $e");
        return;
      }
    }

    startScan();
  }

  void startScan() async {
    isConnecting.value = true;
    devices.clear();
    await requestPermissions();

    bool? isOn = await FlutterBluetoothSerial.instance.isEnabled;
    if (!isOn!) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    final seenAddresses = <String>{};

    final StreamSubscription<BluetoothDiscoveryResult> subscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
          if (!seenAddresses.contains(r.device.address)) {
            seenAddresses.add(r.device.address);
            devices.add(r.device);
          }
        });

    // หยุดการสแกนหลังจาก 5 วินาที
    Future.delayed(Duration(seconds: 5), () async {
      await subscription.cancel();
      isConnecting.value = false;
    });
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

  // เพิ่มฟังก์ชันสำหรับฟังข้อมูลที่ส่งกลับมา
  void _startListeningForData() {
    if (bluetoothService.connection == null) return;

    _dataSubscription = bluetoothService.connection!.input!.listen(
      (Uint8List data) {
        _handleReceivedData(data);
      },
      onError: (error) {
        print("Error receiving data: $error");
      },
    );
  }

  // ฟังก์ชันสำหรับจัดการข้อมูลที่รับเข้ามา
  void _handleReceivedData(Uint8List data) {
    // แสดงข้อมูลที่รับมาในรูปแบบ hex
    String hexData = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    print("📥 Received data (${data.length} bytes): $hexData");
    
    // แสดงข้อมูลที่รับมาให้ผู้ใช้เห็น (สำหรับ debug)
    Get.snackbar(
      "📥 ข้อมูลที่รับมา",
      "Length: ${data.length} bytes\nHex: ${hexData.length > 50 ? hexData.substring(0, 50) + '...' : hexData}",
      backgroundColor: Colors.blue.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 5),
      snackPosition: SnackPosition.TOP,
    );
    
    // ตรวจสอบรูปแบบการตอบกลับจากอุปกรณ์จริง
    // รูปแบบที่ได้รับ: A2 F1 11 [command] 00 00 ... [checksum] E2
    if (data.length == 64 && 
        data[0] == 0xA2 &&  // Header byte 1
        data[1] == 0xF1 &&  // Header byte 2  
        data[2] == 0x11 &&  // Header byte 3
        data[63] == 0xE2) { // End byte
      
      int responseCommand = data[3];
      print("📋 Valid response packet - Command: 0x${responseCommand.toRadixString(16).padLeft(2, '0').toUpperCase()}");
      
      // ตรวจสอบ checksum
      if (_validateResponseChecksum(data)) {
        // ตรวจสอบว่าเป็นการตอบกลับจากคำสั่งไหน
        if (responseCommand == 0x01) {
          // ตอบกลับจากคำสั่ง Activate Connect
          _handleConnectResponse("Connect Command (0x01)", responseCommand);
        } else if (responseCommand == 0x02) {
          // ตอบกลับจากคำสั่ง Activate Now
          _handleActivateResponse("Activate Now (0x02)", responseCommand);
        } else if (responseCommand == 0x99) {
          // ตอบกลับจากคำสั่งทดสอบ
          _handleTestResponse("Test Command (0x99)", responseCommand);
        } else {
          // คำสั่งอื่นๆ
          _handleGeneralResponse("Unknown Command", responseCommand);
        }
        return;
      } else {
        print("❌ Checksum ไม่ถูกต้อง");
        Get.snackbar(
          "❌ ข้อผิดพลาด",
          "Checksum ของข้อมูลไม่ถูกต้อง",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      print("⚠️ รูปแบบข้อมูลไม่ตรงกับที่คาดหวัง");
      print("Expected: 64 bytes, A2 F1 11 [cmd] ... E2");
      print("Received: ${data.length} bytes, ${data.take(4).map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')} ... ${data.length > 0 ? data[data.length-1].toRadixString(16).padLeft(2, '0').toUpperCase() : ''}");
    }
  }
  
  // ฟังก์ชันตรวจสอบ checksum สำหรับ response
  bool _validateResponseChecksum(Uint8List data) {
    if (data.length < 64) return false;
    
    int sum = 0;
    for (int i = 0; i < 62; i++) {
      sum += data[i];
    }
    
    bool isValid = (sum & 0xFF) == data[62];
    print("🔍 Checksum validation: calculated=0x${(sum & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}, received=0x${data[62].toRadixString(16).padLeft(2, '0').toUpperCase()}, valid=$isValid");
    
    return isValid;
  }
  
  // ฟังก์ชันแยกสำหรับจัดการเมื่อได้รับการตอบกลับจากคำสั่ง Connect
  void _handleConnectResponse(String responseType, int commandByte) {
    isConnectResponseReceived.value = true;
    canActivate.value = true;
    
    Get.snackbar(
      "🔌 Connect สำเร็จ",
      "✅ อุปกรณ์ตอบกลับคำสั่ง Connect แล้ว\n($responseType)\nสามารถใช้งาน Activate Now ได้",
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 4),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจาก Activate Now
  void _handleActivateResponse(String responseType, int commandByte) {
    Get.snackbar(
      "⚡ Activate สำเร็จ",
      "✅ อุปกรณ์ตอบกลับคำสั่ง Activate Now แล้ว\n($responseType)",
      backgroundColor: Colors.purple.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจากคำสั่งทดสอบ
  void _handleTestResponse(String responseType, int commandByte) {
    Get.snackbar(
      "🔧 ทดสอบสำเร็จ",
      "✅ อุปกรณ์ตอบกลับคำสั่งทดสอบแล้ว\n($responseType)",
      backgroundColor: Colors.orange.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับทั่วไป
  void _handleGeneralResponse(String responseType, int commandByte) {
    Get.snackbar(
      "📡 ได้รับการตอบกลับ",
      "✅ Command: 0x${commandByte.toRadixString(16).padLeft(2, '0').toUpperCase()}\n($responseType)",
      backgroundColor: Colors.teal.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void sendUnlockCommand() {
    bluetoothService.send("UNLOCK");
  }

  void sendCommand(int commandByte, {String? successMessage}) {
    if (bluetoothService.connection == null) {
      Get.snackbar("ยังไม่ได้เชื่อมต่อ", "กรุณาเชื่อมต่อกับอุปกรณ์ก่อน");
      return;
    }

    List<int> packet = List.filled(64, 0);

    // Header
    packet[0] = 0xA1;
    packet[1] = 0x11;
    packet[2] = 0xF1;

    // Command
    packet[3] = commandByte;

    // Checksum (sum of byte 0..61)
    int sum = 0;
    for (int i = 0; i < 62; i++) {
      sum += packet[i];
    }
    packet[62] = sum & 0xFF;

    // End byte
    packet[63] = 0xE1;

    bluetoothService.connection!.output.add(Uint8List.fromList(packet));
    bluetoothService.connection!.output.allSent.then((_) {
      print("Sent command: $commandByte");
      
      // แสดง snackbar เมื่อส่งเสร็จ
      if (successMessage != null) {
        Get.snackbar(
          "สำเร็จ", 
          successMessage,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }).catchError((error) {
      // แสดง error หากส่งไม่สำเร็จ
      Get.snackbar(
        "ผิดพลาด", 
        "ไม่สามารถส่งคำสั่งได้: $error",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    });
  }

  // แก้ไขฟังก์ชัน activateConnect เพื่อรีเซ็ตสถานะ
  void activateConnect() {
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    sendCommand(0x01, successMessage: "🔌 ส่งคำสั่ง Activate Connect แล้ว กรุณารอการตอบกลับ...");
  }

  // ฟังก์ชันสำหรับการทดสอบ - บังคับให้ถือว่าได้รับการตอบกลับ
  void forceActivateResponse() {
    isConnectResponseReceived.value = true;
    canActivate.value = true;
    
    Get.snackbar(
      "⚠️ บังคับเปิดใช้งาน",
      "✅ บังคับให้ปุ่ม Activate Now ใช้งานได้\n(สำหรับการทดสอบ)",
      backgroundColor: Colors.amber.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
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
    sendCommand(0x02, successMessage: "⚡ ส่งคำสั่ง Activate Now แล้ว");
  }

  void disconnect() async {
    _dataSubscription?.cancel();
    startScan();
    await bluetoothService.disconnect();
    isConnected.value = false;
    selectedDevice.value = null;
    isConnectResponseReceived.value = false;
    canActivate.value = false;
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
      await bluetoothService.connect(device);
      selectedDevice.value = device;
      isConnected.value = true;
      isConnectResponseReceived.value = false;
      canActivate.value = false;

      // เริ่มฟังข้อมูลที่ส่งกลับมา
      _startListeningForData();

      await saveLastConnectedDevice(device.address);
    } catch (e) {
      Get.snackbar("เชื่อมต่อไม่สำเร็จ", e.toString());
    } finally {
      isConnecting.value = false;
    }
  }
}