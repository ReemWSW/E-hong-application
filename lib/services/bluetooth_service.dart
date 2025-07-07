import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class BluetoothService {
  final FlutterBlueClassic _bluetooth = FlutterBlueClassic();
  BluetoothConnection? connection;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    final bonded = await _bluetooth.bondedDevices;
    return bonded ?? [];
  }

  Future<void> connect(BluetoothDevice device) async {
    // ส่งคำสั่ง Activate Connect ทันทีหลังจากเชื่อมต่อ
    try {
      connection = await _bluetooth.connect(device.address);
      if (isConnected) {
       
        await Future.delayed(Duration(milliseconds: 500));
        await sendCmdActivateConnect();
         
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ ไม่สามารถเชื่อมต่อ: $e");
      }
      rethrow;
    }
  }

  void send(String message) {
    connection?.output.add(Uint8List.fromList(message.codeUnits));
    connection?.output.allSent;
  }

  // ส่งคำสั่ง Activate Connect
  Future<void> sendCmdActivateConnect() async {
    if (!isConnected) return;

    Uint8List byteOut = Uint8List(64);

    // เคลียร์ array
    for (int i = 0; i < 64; i++) {
      byteOut[i] = 0;
    }

    // ตั้งค่าข้อมูล
    byteOut[0] = 0xA1;
    byteOut[1] = 0x11;
    byteOut[2] = 0xF1;
    byteOut[3] = 0x01;

    // คำนวณ checksum
    int chksum = 0;
    for (int i = 0; i < 62; i++) {
      chksum = chksum + byteOut[i];
    }
    byteOut[62] = chksum & 0xFF;
    byteOut[63] = 0xE1;

    // ส่งข้อมูล
    connection?.output.add(byteOut);
    connection?.output.allSent;

    if (kDebugMode) {
      print("Sent Activate Connect command");
    }
  }

  // ส่งคำสั่ง Activate Now
  Future<void> sendCmdActivateNow() async {
    if (!isConnected) return;

    try {
      // ส่งคำสั่ง Activate Connect ก่อน
      if (kDebugMode) {
        print("Sending Activate Connect before Activate Now...");
      }
      await sendCmdActivateConnect();

      // รอสักครู่ให้คำสั่งแรกส่งเสร็จ
      await Future.delayed(Duration(milliseconds: 300));

      // ส่งคำสั่ง Activate Now
      if (kDebugMode) {
        print("Sending Activate Now...");
      }
      Uint8List byteOut = Uint8List(64);

      // เคลียร์ array
      for (int i = 0; i < 64; i++) {
        byteOut[i] = 0;
      }

      // ตั้งค่าข้อมูล
      byteOut[0] = 0xA1;
      byteOut[1] = 0x11;
      byteOut[2] = 0xF1;
      byteOut[3] = 0x02;

      // คำนวณ checksum
      int chksum = 0;
      for (int i = 0; i < 62; i++) {
        chksum = chksum + byteOut[i];
      }
      byteOut[62] = chksum & 0xFF;
      byteOut[63] = 0xE1;

      // ส่งข้อมูล
      connection?.output.add(byteOut);
      await connection?.output.allSent;

      if (kDebugMode) {
        print("Sent Activate Now command (after Connect)");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error sending Activate Now sequence: $e");
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await connection?.close();
    connection = null;
  }

  bool get isConnected => connection?.isConnected ?? false;
}
