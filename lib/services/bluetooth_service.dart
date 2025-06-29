import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class BluetoothService {
  final FlutterBlueClassic _bluetooth = FlutterBlueClassic();
  BluetoothConnection? connection;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    final bonded = await _bluetooth.bondedDevices;
    return bonded ?? [];
  }

  Future<void> connect(BluetoothDevice device) async {
    connection = await _bluetooth.connect(device.address);
    
    // ส่งคำสั่ง Activate Connect ทันทีหลังจากเชื่อมต่อ
    if (isConnected) {
      await Future.delayed(Duration(milliseconds: 500)); // รอให้เชื่อมต่อเสถียร
      sendCmdActivateConnect();
    }
  }

  void send(String message) {
    connection?.output.add(Uint8List.fromList(message.codeUnits));
    connection?.output.allSent;
  }

  // ส่งคำสั่ง Activate Connect
  void sendCmdActivateConnect() {
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
    
    print("Sent Activate Connect command");
  }

  // ส่งคำสั่ง Activate Now
  void sendCmdActivateNow() {
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
    byteOut[3] = 0x02; // ต่างจาก Activate Connect ตรงนี้
    
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
    
    print("Sent Activate Now command");
  }

  Future<void> disconnect() async {
    await connection?.close();
    connection = null;
  }

  bool get isConnected => connection?.isConnected ?? false;
}