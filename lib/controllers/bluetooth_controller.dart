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
  var lastCommandSent = 0.obs; // เก็บคำสั่งสุดท้ายที่ส่งไป
  var isWaitingResponse = false.obs; // ตรวจสอบว่ากำลังรอการตอบกลับ

  StreamSubscription<Uint8List>? _dataSubscription;
  Timer? _responseTimeout; // Timer สำหรับ timeout

  @override
  void onInit() {
    super.onInit();
    ensureBluetoothOnThenScan();
    autoReconnect();
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    _responseTimeout?.cancel();
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
        } else if (responseCommand == 0xFF) {
          // ตอบกลับจากคำสั่ง Acknowledge
          _handleAckResponse("Acknowledge (0xFF)", responseCommand);
        } else if (responseCommand == 0x00) {
          // ตอบกลับจากคำสั่ง Complete
          _handleCompleteResponse("Complete (0x00)", responseCommand);
        } else if (responseCommand == 0xEE) {
          // ตอบกลับจากคำสั่ง Stop
          _handleStopResponse("Stop (0xEE)", responseCommand);
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
    // หยุดการรอการตอบกลับ
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
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
    // หยุดการรอการตอบกลับ
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
    // Get.snackbar(
    //   "⚡ Activate สำเร็จ",
    //   "✅ อุปกรณ์ตอบกลับคำสั่ง Activate Now แล้ว\n($responseType)\n💡 ลองกดปุ่ม ACK, DONE หรือ STOP",
    //   backgroundColor: Colors.purple.withOpacity(0.8),
    //   colorText: Colors.white,
    //   duration: Duration(seconds: 5),
    //   snackPosition: SnackPosition.BOTTOM,
    // );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจากคำสั่งทดสอบ
  void _handleTestResponse(String responseType, int commandByte) {
    // หยุดการรอการตอบกลับ
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
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
    // หยุดการรอการตอบกลับ
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
    Get.snackbar(
      "📡 ได้รับการตอบกลับ",
      "✅ Command: 0x${commandByte.toRadixString(16).padLeft(2, '0').toUpperCase()}\n($responseType)",
      backgroundColor: Colors.teal.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจาก Acknowledge
  void _handleAckResponse(String responseType, int commandByte) {
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
    Get.snackbar(
      "📨 ACK รับทราบ",
      "✅ อุปกรณ์รับทราบคำสั่ง Acknowledge",
      backgroundColor: Colors.teal.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจาก Complete
  void _handleCompleteResponse(String responseType, int commandByte) {
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
    Get.snackbar(
      "✅ Complete รับทราบ",
      "✅ อุปกรณ์รับทราบสัญญาณเสร็จสิ้น",
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }
  
  // ฟังก์ชันจัดการการตอบกลับจาก Stop
  void _handleStopResponse(String responseType, int commandByte) {
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
    
    Get.snackbar(
      "🛑 Stop รับทราบ",
      "✅ อุปกรณ์หยุดการทำงานแล้ว",
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      duration: Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void sendUnlockCommand() {
    bluetoothService.send("UNLOCK");
  }

  void sendCommand(int commandByte, {String? successMessage}) {
    // ตรวจสอบการเชื่อมต่อ Bluetooth อย่างละเอียด
    if (bluetoothService.connection == null || !bluetoothService.connection!.isConnected) {
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

    // ตรวจสอบสถานะการเชื่อมต่อเพิ่มเติม
    if (!isConnected.value) {
      Get.snackbar(
        "❌ การเชื่อมต่อขาดหาย", 
        "การเชื่อมต่อ Bluetooth หลุด กรุณาเชื่อมต่อใหม่",
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
      // รีเซ็ตสถานะ
      isConnected.value = false;
      selectedDevice.value = null;
      return;
    }

    // ป้องกันการส่งคำสั่งซ้ำๆ ในช่วงเวลาสั้นๆ
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

      // เก็บข้อมูลคำสั่งที่ส่งไป
      lastCommandSent.value = commandByte;
      isWaitingResponse.value = true;

      // ตั้ง timeout สำหรับการรอการตอบกลับ (10 วินาที)
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

      // ส่งข้อมูลและจัดการ error
      bluetoothService.connection!.output.add(Uint8List.fromList(packet));
      bluetoothService.connection!.output.allSent.then((_) {
        print("Sent command: $commandByte (0x${commandByte.toRadixString(16).padLeft(2, '0').toUpperCase()})");
        
        // แสดง snackbar เมื่อส่งเสร็จ
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
        // หยุดการรอและแสดง error
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
        
        // รีเซ็ตการเชื่อมต่อ
        isConnected.value = false;
        selectedDevice.value = null;
      });
      
    } catch (e) {
      // จัดการ error ที่เกิดขึ้นก่อนส่งข้อมูล
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
      
      // รีเซ็ตสถานะการเชื่อมต่อ
      isConnected.value = false;
      selectedDevice.value = null;
    }
  }

  // แก้ไขฟังก์ชัน activateConnect เพื่อรีเซ็ตสถานะ
  void activateConnect() {
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    sendCommand(0x01, successMessage: "🔌 ส่งคำสั่ง Activate Connect แล้ว กรุณารอการตอบกลับ...");
  }

  // ฟังก์ชันสำหรับส่งคำสั่งยืนยัน
  void sendAcknowledge() {
    sendCommand(0xFF, successMessage: "📨 ส่งยืนยันการรับข้อมูล (ACK)");
  }
  
  // ฟังก์ชันสำหรับส่งคำสั่งเสร็จสิ้น
  void sendComplete() {
    sendCommand(0x00, successMessage: "✅ ส่งสัญญาณเสร็จสิ้น (COMPLETE)");
  }
  
  // ฟังก์ชันสำหรับหยุดการทำงานของอุปกรณ์
  void sendStop() {
    sendCommand(0xEE, successMessage: "🛑 ส่งคำสั่งหยุด (STOP)");
  }

  // ฟังก์ชันสำหรับรีเซ็ตสถานะการรอ (public)
  void resetWaitingState() {
    isWaitingResponse.value = false;
    _responseTimeout?.cancel();
  }

  // ฟังก์ชันสำหรับการทดสอบ - บังคับให้ถือว่าได้รับการตอบกลับ
  void forceActivateResponse() {
    isConnectResponseReceived.value = true;
    canActivate.value = true;
    resetWaitingState(); // รีเซ็ตสถานะการรอด้วย
    
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
    _responseTimeout?.cancel();
    
    // รีเซ็ตสถานะทั้งหมด
    isWaitingResponse.value = false;
    isConnectResponseReceived.value = false;
    canActivate.value = false;
    lastCommandSent.value = 0;
    
    startScan();
    await bluetoothService.disconnect();
    isConnected.value = false;
    selectedDevice.value = null;
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
      
      // ตัดการเชื่อมต่อเดิม (ถ้ามี)
      if (bluetoothService.connection != null) {
        await bluetoothService.disconnect();
      }
      
      // เชื่อมต่อใหม่
      await bluetoothService.connect(device);
      
      // ตรวจสอบว่าเชื่อมต่อสำเร็จจริงๆ
      if (bluetoothService.connection != null && bluetoothService.connection!.isConnected) {
        selectedDevice.value = device;
        isConnected.value = true;
        isConnectResponseReceived.value = false;
        canActivate.value = false;

        // เริ่มฟังข้อมูลที่ส่งกลับมา
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
      
      // รีเซ็ตสถานะเมื่อเชื่อมต่อไม่สำเร็จ
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